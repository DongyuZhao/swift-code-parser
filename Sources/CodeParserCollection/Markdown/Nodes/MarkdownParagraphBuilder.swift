import CodeParserCore
import Foundation

/// Handles paragraph nodes - serves as the fallback builder for any remaining content
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#paragraphs
public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    let startIndex = state.position
    
    // If this is a blank line (empty tokens array), don't handle it
    guard startIndex < context.tokens.count else {
      return false
    }

    let remainingTokens = Array(context.tokens[startIndex...])
    
    // Check if this line is blank - close paragraph context but return true to propagate changes
    if isBlankLine(remainingTokens) {
      // If we're currently in a paragraph, move context up to close it
      if context.current.element == .paragraph {
        if let parent = context.current.parent {
          context.current = parent
        }
      }
      // Return true to ensure context changes are propagated, but don't consume tokens
      return true
    }

    // Find end of content (before newline)
    var contentEnd = context.tokens.count
    for i in startIndex..<context.tokens.count {
      if context.tokens[i].element == .newline {
        contentEnd = i
        break
      }
    }
    
    // Collect tokens for this line (excluding newline)
    var contentTokens = Array(context.tokens[startIndex..<contentEnd])
    
    // Strip leading and trailing whitespace from paragraph content
    while !contentTokens.isEmpty && contentTokens[0].element == .whitespaces {
      contentTokens.removeFirst()
    }
    while !contentTokens.isEmpty && contentTokens.last!.element == .whitespaces {
      contentTokens.removeLast()
    }

    // Check if we're currently in a paragraph context
    if context.current.element == .paragraph {
      // We're in an existing paragraph, find the last ContentNode and append tokens to it
      if let lastChild = context.current.children.last as? ContentNode {
        // Add newline token to represent the line break, then append new content tokens
        let newlineToken = MarkdownToken(element: .newline, text: "\n", range: "".startIndex..<"".endIndex)
        lastChild.tokens.append(newlineToken)
        lastChild.tokens.append(contentsOf: contentTokens)
      } else {
        // Fallback: create new content node if no existing ContentNode found
        let contentNode = ContentNode(tokens: contentTokens)
        context.current.append(contentNode)
      }
    } else {
      // Check if we're in a container context (like blockquote) but this line doesn't belong to it
      if context.current.element == .blockquote {
        // Check if this line starts with blockquote marker
        let hasBlockquoteMarker = startIndex < context.tokens.count && 
                                 context.tokens[startIndex].element == .punctuation &&
                                 context.tokens[startIndex].text == ">"
        
        if !hasBlockquoteMarker {
          // This line doesn't belong to the blockquote, exit to parent
          if let parent = context.current.parent {
            context.current = parent
          }
        }
      }
      
      // Create new paragraph (context should be at document level if blank line closed previous paragraph)
      let paragraph = ParagraphNode(range: "".startIndex..<"".endIndex) // TODO: proper range
      let contentNode = ContentNode(tokens: contentTokens)
      paragraph.append(contentNode)
      context.current.append(paragraph)
      
      // Set current context to the new paragraph for potential continuation
      context.current = paragraph
    }

    // After processing a line, ensure we're not leaving current on a content node
    // Move current back to paragraph level if we're deeper
    while context.current.element == .content {
      if let parent = context.current.parent {
        context.current = parent
      } else {
        break
      }
    }

    return true
  }
  
  // Check if this line is blank (only whitespace)
  private func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    for token in tokens {
      switch token.element {
      case .whitespaces, .newline:
        continue
      default:
        return false
      }
    }
    return true
  }
}
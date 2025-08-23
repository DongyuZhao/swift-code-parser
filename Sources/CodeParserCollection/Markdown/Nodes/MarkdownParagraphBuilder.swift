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

    // Skip leading whitespace to find actual content
    var index = startIndex
    while index < context.tokens.count {
      let token = context.tokens[index]
      if token.element == .newline {
        // This line is only whitespace + newline - it's blank
        return false
      } else if token.element == .whitespaces {
        index += 1
      } else {
        // Found non-whitespace content
        break
      }
    }
    
    // If we reached the end without finding content, it's a blank line
    guard index < context.tokens.count else {
      return false
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
    let contentTokens = Array(context.tokens[startIndex..<contentEnd])
    
    // Check if we can continue an existing paragraph (only if there was no blank line separator)
    // Note: The MarkdownBlockBuilder calls each builder per line, so if there was a blank line
    // between this line and the previous paragraph, we should create a new paragraph
    if let lastChild = context.current.children.last as? ParagraphNode,
       canContinueParagraph() {
      // Add a soft line break to separate the lines
      let lineBreak = LineBreakNode(variant: .soft)
      lastChild.append(lineBreak)
      
      // Add content to existing paragraph
      let contentNode = ContentNode(tokens: contentTokens)
      lastChild.append(contentNode)
    } else {
      // Create new paragraph
      let paragraph = ParagraphNode(range: "".startIndex..<"".endIndex) // TODO: proper range
      let contentNode = ContentNode(tokens: contentTokens)
      paragraph.append(contentNode)
      context.current.append(paragraph)
    }

    return true
  }
  
  // Paragraphs continue unless interrupted by a blank line or other block element
  private func canContinueParagraph() -> Bool {
    // For now, always continue - blank line separation is handled by the block builder architecture
    return true
  }
}
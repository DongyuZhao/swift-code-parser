import CodeParserCore
import Foundation

/// Handles thematic breaks (horizontal rules) made with ***, ---, or ___
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#thematic-breaks
public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
  guard context.state is MarkdownConstructState else {
      return false
    }

  // In phased pipeline, builders receive the suffix tokens; always start at local 0
  let startIndex = 0
    guard startIndex < context.tokens.count else {
      return false
    }

    var index = startIndex
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
  while index < context.tokens.count,
      context.tokens[index].element == .whitespaces {
    let spaceCount = context.tokens[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Must start with a valid thematic break character
    guard index < context.tokens.count else { return false }
    
    let thematicChar: String
    if context.tokens[index].element == .punctuation {
      switch context.tokens[index].text {
      case "*", "-", "_":
        thematicChar = context.tokens[index].text
      default:
        return false
      }
    } else {
      return false
    }
    
    // Count occurrences of the thematic character, allowing whitespace in between
    var charCount = 0
    var hasNonWhitespaceNonThematic = false
    
    while index < context.tokens.count {
  let token = context.tokens[index]
  if token.element == .punctuation && token.text == thematicChar {
        charCount += 1
        index += 1
      } else if token.element == .whitespaces {
        // Whitespace is allowed between thematic characters
        index += 1
      } else if token.element == .newline {
        // End of line - stop processing
        break
      } else {
        // Any other character makes this not a thematic break
        hasNonWhitespaceNonThematic = true
        break
      }
    }
    
    // Must have at least 3 thematic characters and no other non-whitespace content
    guard charCount >= 3 && !hasNonWhitespaceNonThematic else {
      return false
    }
    
    // Thematic breaks interrupt paragraphs and blockquotes (if not quoted)
    // If we're in a paragraph context, close it
    if context.current.element == .paragraph {
      if let parent = context.current.parent {
        context.current = parent
      }
    }
    
    // If we're inside a container (blockquote or list) but this line is not properly
    // continued (no > prefix for blockquotes, no proper indentation for lists),
    // the thematic break should be at document level, outside the container
    if isInsideContainer(context: context) {
      // Exit the container context to place thematic break at document level
      context.current = findDocumentLevel(context: context)
    }
    
    // Create thematic break
    let thematicBreak = ThematicBreakNode(marker: String(repeating: thematicChar, count: charCount))
    context.current.append(thematicBreak)

    return true
  }

  private func isInsideContainer(context: CodeConstructContext<Node, Token>) -> Bool {
    // Walk up the context hierarchy to see if we're inside a container (blockquote or list)
    var current: MarkdownNodeBase? = context.current as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode || node is ListItemNode {
        return true
      }
      current = node.parent()
    }
    return false
  }

  private func findDocumentLevel(context: CodeConstructContext<Node, Token>) -> CodeNode<MarkdownNodeElement> {
    // Walk up to find the document level (root or first non-container ancestor)
    var current = context.current
    while let parent = current.parent {
      if let markdownParent = parent as? MarkdownNodeBase,
         !(markdownParent is BlockquoteNode) && !(markdownParent is ListItemNode) && !(markdownParent is ListNode) {
        return parent
      }
      current = parent
    }
    return current
  }
}
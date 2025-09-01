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

    // Before processing as thematic break, check if this could be a setext heading underline
    if let setextInfo = checkSetextUnderline(tokens: context.tokens, startIndex: startIndex) {
      // Check if we're currently in a paragraph context
      if context.current.element == .paragraph, let parent = context.current.parent {
        // The preceding paragraph is the current paragraph context
        let paragraphToConvert = context.current
        
        // Convert the paragraph to a heading
        let heading = HeaderNode(level: setextInfo.level)
        
        // Move all children from paragraph to heading
        while let child = paragraphToConvert.children.first {
          child.remove()
          heading.append(child)
        }

        // Replace paragraph with heading in parent
        let insertIndex = parent.children.firstIndex { $0 === paragraphToConvert } ?? (parent.children.count - 1)
        paragraphToConvert.remove()
        parent.insert(heading, at: insertIndex)

        // Update context to point to parent since we replaced the current paragraph
        context.current = parent

        return true
      }
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
    guard index < context.tokens.count else { 
      return false 
    }

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

  private func checkSetextUnderline(
    tokens: [any CodeToken<MarkdownTokenElement>],
    startIndex: Int
  ) -> (level: Int, endIndex: Int)? {
    var index = startIndex

    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      let spaceCount = tokens[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return nil
      }
      leadingSpaces += spaceCount
      index += 1
    }

    // Must have at least one underline character
    guard index < tokens.count else {
      return nil
    }

    // Determine underline character and level
    let underlineChar: String
    let level: Int

    if tokens[index].element == .punctuation {
      switch tokens[index].text {
      case "=":
        underlineChar = "="
        level = 1
      case "-":
        underlineChar = "-"
        level = 2
      default:
        return nil
      }
    } else {
      return nil
    }

    // Count consecutive underline characters (must be at least 1)
    var underlineCount = 0
    while index < tokens.count,
          tokens[index].element == .punctuation,
          tokens[index].text == underlineChar {
      underlineCount += 1
      index += 1
    }

    guard underlineCount >= 1 else { return nil }

    // Skip trailing whitespace
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      index += 1
    }

    // Must be at end of line (or have newline)
    if index < tokens.count {
      if tokens[index].element != .newline {
        return nil
      }
    }

    return (level: level, endIndex: index)
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
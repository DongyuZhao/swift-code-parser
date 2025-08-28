import CodeParserCore
import Foundation

/// Handles Setext headings (underline style with = and -)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#setext-headings
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.state is MarkdownConstructState else {
      return false
    }

    // Setext headings require checking if the current line is an underline
    // and if there's a previous paragraph to convert

    // Check if this line is a setext underline
  // Builders in phased pipeline receive the suffix tokens; always start at local 0
  guard let underlineInfo = checkSetextUnderline(tokens: context.tokens, startIndex: 0) else {
      return false
    }

    // Look for a preceding paragraph to convert
    // Setext headings can only be formed when the underline immediately follows a paragraph
    // If there was a blank line before the underline, the paragraph context would have been closed
    // and we should treat this as a thematic break instead
    
    // Check if we're currently in a paragraph context (no blank line before)
    if context.current.element == .paragraph {
      // Check if we're inside a blockquote
      // According to CommonMark spec, setext heading underlines cannot be lazy continuation lines in blockquotes
      if isInsideBlockquote(context: context) {
        // We're inside a blockquote - the underline should be treated as lazy continuation text
        // or as a thematic break, not as a setext heading underline
        return false
      }
      
      // We're in a paragraph, use the parent (document level) to replace the paragraph
      guard let parent = context.current.parent else { return false }
      let documentLevel = parent
      let lastChild = context.current // The current paragraph
      
      // Convert the paragraph to a heading
      let heading = HeaderNode(level: underlineInfo.level)
      
      // Move all children from paragraph to heading
      while let child = lastChild.children.first {
        child.remove()
        heading.append(child)
      }
      
      // Replace paragraph with heading
      let insertIndex = documentLevel.children.firstIndex { $0 === lastChild } ?? 0
      lastChild.remove()
      documentLevel.insert(heading, at: insertIndex)
      
      // Update context current to be at document level
      context.current = documentLevel
      
      return true
    } else {
      // We're not in a paragraph context, which means there was a blank line before
      // Don't treat this as a setext heading underline - let thematic break handle it
      return false
    }
  }

  private func isInsideBlockquote(context: CodeConstructContext<Node, Token>) -> Bool {
    // Walk up the context hierarchy to see if we're inside a blockquote
    var current: MarkdownNodeBase? = context.current as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode {
        return true
      }
      current = node.parent()
    }
    return false
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
}
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

    // In the postParagraph phase, we need to check if the current line is a setext underline
    // and if there's a previous paragraph (now a completed child) to convert
    
    // Check if this line is a setext underline
    guard let underlineInfo = checkSetextUnderline(tokens: context.tokens, startIndex: 0) else {
      return false
    }

    // Look for a preceding paragraph to convert
    // In the postParagraph phase, the preceding paragraph should be the last child of the current context
    guard let lastChild = context.current.children.last,
          lastChild.element == .paragraph else {
      // No preceding paragraph found
      return false
    }

    // Check if we're inside a container where setext headings cannot be formed
    // According to CommonMark spec, setext heading underlines cannot be lazy continuation lines in blockquotes or list items
    if isInsideContainer(context: context, checkingNode: lastChild) {
      // We're inside a container - the underline should be treated as lazy continuation text
      // or as a thematic break, not as a setext heading underline
      return false
    }

    // Convert the paragraph to a heading
    let heading = HeaderNode(level: underlineInfo.level)

    // Move all children from paragraph to heading
    while let child = lastChild.children.first {
      child.remove()
      heading.append(child)
    }

    // Replace paragraph with heading
    let insertIndex = context.current.children.firstIndex { $0 === lastChild } ?? (context.current.children.count - 1)
    lastChild.remove()
    context.current.insert(heading, at: insertIndex)

    return true
  }

  private func isInsideContainer(context: CodeConstructContext<Node, Token>, checkingNode: CodeNode<MarkdownNodeElement>) -> Bool {
    // Walk up the hierarchy from the node being checked to see if it's inside a container
    var current: MarkdownNodeBase? = checkingNode.parent as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode || node is ListItemNode {
        return true
      }
      current = node.parent as? MarkdownNodeBase
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
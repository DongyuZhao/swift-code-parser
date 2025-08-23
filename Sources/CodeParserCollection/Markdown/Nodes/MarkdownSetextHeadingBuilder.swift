import CodeParserCore
import Foundation

/// Handles Setext headings (underline style with = and -)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#setext-headings
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    // Setext headings require checking if the current line is an underline
    // and if there's a previous paragraph to convert

    // Check if this line is a setext underline
    guard let underlineInfo = checkSetextUnderline(tokens: context.tokens, startIndex: state.position) else {
      return false
    }

    // Look for a preceding paragraph to convert
    guard let lastChild = context.current.children.last as? MarkdownNodeBase,
          lastChild.element == .paragraph else {
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
    let insertIndex = context.current.children.firstIndex { $0 === lastChild } ?? 0
    lastChild.remove()
    context.current.insert(heading, at: insertIndex)

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
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      let spaceCount = token.text.count
      if leadingSpaces + spaceCount > 3 {
        return nil
      }
      leadingSpaces += spaceCount
      index += 1
    }

    // Must have at least one underline character
    guard index < tokens.count else { return nil }

    // Determine underline character and level
    let underlineChar: String
    let level: Int

    if let firstToken = tokens[index] as? any CodeToken<MarkdownTokenElement>,
       firstToken.element == .punctuation {
      switch firstToken.text {
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
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == underlineChar {
      underlineCount += 1
      index += 1
    }

    guard underlineCount >= 1 else { return nil }

    // Skip trailing whitespace
    while index < tokens.count,
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      index += 1
    }

    // Must be at end of line (or have newline)
    if index < tokens.count {
      if let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
         token.element != .newline {
        return nil
      }
    }

    return (level: level, endIndex: index)
  }
}
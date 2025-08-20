import CodeParserCore
import Foundation

/// Builder for Markdown paragraph blocks. Paragraphs are sequences of
/// non-blank lines separated by one or more blank lines.
public struct MarkdownParagraphNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  /// Parse a paragraph from the token stream. This follows the block
  /// structure rules from the CommonMark specification: a paragraph starts
  /// with a non-blank line and continues until a blank line or EOF.
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Save starting position
    let startIndex = context.consuming
    guard startIndex < context.tokens.count else { return false }

    // Paragraph cannot start with a blank line
    if isBlankLine(from: startIndex, in: context) { return false }

    var current = startIndex
    var endIndex = startIndex
    var sawContent = false

    while current < context.tokens.count {
      guard let token = context.tokens[current] as? MarkdownToken else { break }
      switch token.element {
      case .newline, .hardbreak, .eof:
        endIndex = current
        current += 1
        // Stop at first blank line
        if isBlankLine(from: current, in: context) { break }
      default:
        sawContent = true
        current += 1
      }
    }

    guard sawContent else { return false }

    // Compute range from first to last consumed token
    let startToken = context.tokens[startIndex] as! MarkdownToken
    let endToken = context.tokens[max(startIndex, endIndex - 1)] as! MarkdownToken
    let range = startToken.range.lowerBound..<endToken.range.upperBound
    let node = ParagraphNode(range: range)
    context.current.append(node)
    context.consuming = current
    return true
  }

  /// Determine if the tokens starting at index represent a blank line.
  private func isBlankLine(from index: Int, in context: CodeConstructContext<Node, Token>) -> Bool {
    var i = index
    while i < context.tokens.count {
      guard let token = context.tokens[i] as? MarkdownToken else { return true }
      if token.element == .newline || token.element == .hardbreak || token.element == .eof {
        return true
      }
      if token.element != .whitespaces { return false }
      i += 1
    }
    return true
  }
}


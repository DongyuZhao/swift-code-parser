import CodeParserCore
import Foundation

/// Builder for ATX Markdown headings using leading `#` characters.
/// Setext headings are not yet supported.
public struct MarkdownHeadingNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count else { return false }

    var current = start
    var level = 0

    while current < context.tokens.count {
      guard let token = context.tokens[current] as? MarkdownToken else { break }
      if token.element == .punctuation && token.text == "#" { level += 1; current += 1 }
      else { break }
    }
    guard level > 0 && level <= 6 else { return false }

    // Require a space after the marker (spec requirement)
    if current < context.tokens.count, let token = context.tokens[current] as? MarkdownToken,
       token.element == .whitespaces {
      current += 1
    } else { return false }

    // Consume heading text until end of line
    var end = current
    while end < context.tokens.count {
      guard let tok = context.tokens[end] as? MarkdownToken else { break }
      if tok.element == .newline || tok.element == .hardbreak || tok.element == .eof { break }
      end += 1
    }
    guard end > current else { return false }

    // Compute range for completeness even though HeaderNode currently does not
    // store source ranges.
    let startToken = context.tokens[start] as! MarkdownToken
    let endToken = context.tokens[end - 1] as! MarkdownToken
    _ = startToken.range.lowerBound..<endToken.range.upperBound
    let node = HeaderNode(level: level)
    context.current.append(node)
    context.consuming = end
    return true
  }
}


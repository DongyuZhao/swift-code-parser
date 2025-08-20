import CodeParserCore
import Foundation

/// Builder for thematic breaks (horizontal rules) which are lines consisting
/// of three or more `-`, `*`, or `_` characters possibly separated by spaces.
public struct MarkdownThematicBreakNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count else { return false }

    var current = start
    // Skip leading spaces
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .whitespaces {
      current += 1
    }

    guard current < context.tokens.count else { return false }

    var marker: String?
    var count = 0
    var i = current
    while i < context.tokens.count {
      guard let tok = context.tokens[i] as? MarkdownToken else { break }
      switch tok.element {
      case .punctuation:
        if marker == nil { marker = tok.text }
        guard tok.text == marker && ["-", "*", "_"] .contains(tok.text) else { return false }
        count += 1
        i += 1
      case .whitespaces:
        i += 1
      case .newline, .hardbreak, .eof:
        // End of line
        context.current.append(ThematicBreakNode())
        context.consuming = i
        return count >= 3
      default:
        return false
      }
    }
    return false
  }
}


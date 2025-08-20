import CodeParserCore
import Foundation

/// Builder for image blocks of the form `![alt](url)` on its own line.
/// This is a simplified recognizer primarily for demonstration purposes.
public struct MarkdownImageBlockNodeBuilder: CodeNodeBuilder {
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

    guard current + 1 < context.tokens.count,
          let bang = context.tokens[current] as? MarkdownToken,
          let open = context.tokens[current + 1] as? MarkdownToken,
          bang.element == .punctuation, bang.text == "!",
          open.element == .punctuation, open.text == "[" else { return false }
    current += 2

    // Alt text
    var alt = ""
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken {
      if tok.element == .punctuation && tok.text == "]" { break }
      alt += tok.text
      current += 1
    }
    guard current < context.tokens.count,
          let closeBracket = context.tokens[current] as? MarkdownToken,
          closeBracket.element == .punctuation, closeBracket.text == "]" else { return false }
    current += 1

    guard current < context.tokens.count,
          let openParen = context.tokens[current] as? MarkdownToken,
          openParen.element == .punctuation, openParen.text == "(" else { return false }
    current += 1

    var url = ""
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken {
      if tok.element == .punctuation && tok.text == ")" { break }
      url += tok.text
      current += 1
    }
    guard current < context.tokens.count,
          let closeParen = context.tokens[current] as? MarkdownToken,
          closeParen.element == .punctuation, closeParen.text == ")" else { return false }
    current += 1

    let node = ImageBlockNode(url: url, alt: alt)
    context.current.append(node)
    context.consuming = current
    return true
  }
}


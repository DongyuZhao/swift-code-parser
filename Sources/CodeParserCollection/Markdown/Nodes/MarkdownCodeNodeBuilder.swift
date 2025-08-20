import CodeParserCore
import Foundation

/// Builder for inline code spans using backtick delimiters.
public struct MarkdownCodeNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count,
          let token = context.tokens[start] as? MarkdownToken,
          token.element == .punctuation, token.text == "`" else { return false }

    var current = start + 1
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == "`" {
        let slice = context.tokens[(start + 1)..<current]
        let code = tokensToString(slice)
        let node = CodeSpanNode(code: code)
        context.current.append(node)
        context.consuming = current + 1
        return true
      }
      current += 1
    }
    return false
  }
}

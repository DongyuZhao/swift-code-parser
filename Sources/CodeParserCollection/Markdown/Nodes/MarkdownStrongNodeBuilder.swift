import CodeParserCore
import Foundation

/// Builder for inline strong emphasis using ** or __ delimiters.
public struct MarkdownStrongNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start + 1 < context.tokens.count,
          let first = context.tokens[start] as? MarkdownToken,
          let second = context.tokens[start + 1] as? MarkdownToken,
          first.element == .punctuation,
          second.element == .punctuation,
          first.text == second.text,
          (first.text == "*" || first.text == "_") else { return false }
    let delimiter = first.text
    var current = start + 2
    while current + 1 < context.tokens.count {
      guard let tok1 = context.tokens[current] as? MarkdownToken,
            let tok2 = context.tokens[current + 1] as? MarkdownToken else { break }
      if tok1.element == .punctuation && tok2.element == .punctuation && tok1.text == delimiter && tok2.text == delimiter {
        let slice = context.tokens[(start + 2)..<current]
        let content = tokensToString(slice)
        let strong = StrongNode(content: content)
        if !content.isEmpty {
          strong.append(TextNode(content: content))
        }
        context.current.append(strong)
        context.consuming = current + 2
        return true
      }
      current += 1
    }
    return false
  }
}

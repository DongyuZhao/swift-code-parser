import CodeParserCore
import Foundation

/// Builder for inline emphasis using * or _ delimiters.
public struct MarkdownEmphasisNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count,
          let token = context.tokens[start] as? MarkdownToken,
          token.element == .punctuation,
          token.text == "*" || token.text == "_" else { return false }
    let delimiter = token.text
    var current = start + 1
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == delimiter {
        let slice = context.tokens[(start + 1)..<current]
        let content = tokensToString(slice)
        let emphasis = EmphasisNode(content: content)
        // Append inner text as child
        if !content.isEmpty {
          emphasis.append(TextNode(content: content))
        }
        context.current.append(emphasis)
        context.consuming = current + 1
        return true
      }
      current += 1
    }
    return false
  }
}

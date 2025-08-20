import CodeParserCore
import Foundation

/// Builder for inline HTML segments enclosed in < and >.
public struct MarkdownHTMLNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count,
          let open = context.tokens[start] as? MarkdownToken,
          open.element == .punctuation, open.text == "<" else { return false }
    var current = start + 1
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == ">" {
        let slice = context.tokens[start...current]
        let content = tokensToString(slice)
        let html = HTMLNode(content: content)
        context.current.append(html)
        context.consuming = current + 1
        return true
      }
      current += 1
    }
    return false
  }
}

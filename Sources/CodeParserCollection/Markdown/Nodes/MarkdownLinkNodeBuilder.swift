import CodeParserCore
import Foundation

/// Builder for inline links of the form [text](url).
public struct MarkdownLinkNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count,
          let open = context.tokens[start] as? MarkdownToken,
          open.element == .punctuation, open.text == "[" else { return false }
    var current = start + 1
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == "]" { break }
      current += 1
    }
    guard current < context.tokens.count,
          let close = context.tokens[current] as? MarkdownToken,
          close.element == .punctuation, close.text == "]" else { return false }
    let textSlice = context.tokens[(start + 1)..<current]
    let linkText = tokensToString(textSlice)
    var idx = current + 1
    guard idx < context.tokens.count,
          let lpar = context.tokens[idx] as? MarkdownToken,
          lpar.element == .punctuation, lpar.text == "(" else { return false }
    idx += 1
    var urlEnd = idx
    while urlEnd < context.tokens.count {
      guard let tok = context.tokens[urlEnd] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == ")" { break }
      urlEnd += 1
    }
    guard urlEnd < context.tokens.count,
          let rpar = context.tokens[urlEnd] as? MarkdownToken,
          rpar.element == .punctuation, rpar.text == ")" else { return false }
    let urlSlice = context.tokens[idx..<urlEnd]
    let url = tokensToString(urlSlice)
    let link = LinkNode(url: url, title: "")
    if !linkText.isEmpty {
      link.append(TextNode(content: linkText))
    }
    context.current.append(link)
    context.consuming = urlEnd + 1
    return true
  }
}

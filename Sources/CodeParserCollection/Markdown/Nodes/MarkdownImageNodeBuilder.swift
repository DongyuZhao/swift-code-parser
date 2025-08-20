import CodeParserCore
import Foundation

/// Builder for inline images of the form ![alt](url).
public struct MarkdownImageNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start + 1 < context.tokens.count,
          let bang = context.tokens[start] as? MarkdownToken,
          let open = context.tokens[start + 1] as? MarkdownToken,
          bang.element == .punctuation, bang.text == "!",
          open.element == .punctuation, open.text == "[" else { return false }
    var current = start + 2
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .punctuation && tok.text == "]" { break }
      current += 1
    }
    guard current < context.tokens.count,
          let close = context.tokens[current] as? MarkdownToken,
          close.element == .punctuation, close.text == "]" else { return false }
    let altSlice = context.tokens[(start + 2)..<current]
    let altText = tokensToString(altSlice)
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
    let image = ImageNode(url: url, alt: altText, title: "")
    context.current.append(image)
    context.consuming = urlEnd + 1
    return true
  }
}

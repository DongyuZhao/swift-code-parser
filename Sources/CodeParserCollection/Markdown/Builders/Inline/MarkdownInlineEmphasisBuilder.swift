import CodeParserCore
import Foundation

/// Build emphasis (*...*)
struct MarkdownInlineEmphasisBuilder: CodeNodeBuilder {
  typealias Node = MarkdownNodeElement
  typealias Token = MarkdownTokenElement

  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var i = context.consuming
    guard i < tokens.count else { return false }
    let t = tokens[i]
    guard t.element == .punctuation, t.text == "*" else { return false }

    var j = i + 1
    var inner: [any CodeToken<MarkdownTokenElement>] = []
    var found = false
    while j < tokens.count {
      let nt = tokens[j]
      if nt.element == .punctuation, nt.text == "*" { found = true; break }
      inner.append(nt)
      j += 1
    }
    if !found { return false }

    let em = EmphasisNode(content: "")
    let innerText = tokensToString(inner[inner.startIndex..<inner.endIndex])
    em.append(TextNode(content: innerText))
    context.current.append(em)
    context.consuming = j + 1
    return true
  }
}

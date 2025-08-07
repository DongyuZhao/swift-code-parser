import CodeParserCore
import Foundation

public class MarkdownReferenceDefinitionBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      isStartOfLine(context),
      let lb = context.tokens[context.consuming] as? MarkdownToken,
      lb.element == .leftBracket
    else { return false }
    var idx = context.consuming + 1
    var isFootnote = false
    var isCitation = false
    if idx < context.tokens.count,
      let caret = context.tokens[idx] as? MarkdownToken,
      caret.element == .caret
    {
      isFootnote = true
      idx += 1
    } else if idx < context.tokens.count,
      let at = context.tokens[idx] as? MarkdownToken,
      at.element == .atSign
    {
      isCitation = true
      idx += 1
    }
    var identifier = ""
    while idx < context.tokens.count,
      let t = context.tokens[idx] as? MarkdownToken,
      t.element != .rightBracket
    {
      identifier += t.text
      idx += 1
    }
    guard idx < context.tokens.count,
      let rb = context.tokens[idx] as? MarkdownToken,
      rb.element == .rightBracket
    else { return false }
    idx += 1
    guard idx < context.tokens.count,
      let colon = context.tokens[idx] as? MarkdownToken,
      colon.element == .colon
    else { return false }
    idx += 1
    // skip spaces
    while idx < context.tokens.count,
      let sp = context.tokens[idx] as? MarkdownToken,
      sp.element == .space
    {
      idx += 1
    }
    var value = ""
    while idx < context.tokens.count,
      let t = context.tokens[idx] as? MarkdownToken,
      t.element != .newline
    {
      value += t.text
      idx += 1
    }
    context.consuming = idx
    if idx < context.tokens.count,
      let nl = context.tokens[idx] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
    if isFootnote {
      let node = FootnoteNode(
        identifier: identifier, content: value, referenceText: nil, range: lb.range)
      context.current.append(node)
    } else if isCitation {
      let node = CitationNode(identifier: identifier, content: value)
      context.current.append(node)
    } else {
      let node = ReferenceNode(identifier: identifier, url: value, title: "")
      context.current.append(node)
    }
    return true
  }

  private func isStartOfLine(
    _ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    if context.consuming == 0 { return true }
    if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
      return prev.element == .newline
    }
    return false
  }
}

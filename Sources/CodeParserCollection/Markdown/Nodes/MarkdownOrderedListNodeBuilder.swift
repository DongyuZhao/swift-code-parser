import CodeParserCore
import Foundation

/// Builder for ordered list items like `1.` or `1)` followed by a space.
/// Creates an `OrderedListNode` containing a single `ListItemNode` with a
/// paragraph child for the line content.
public struct MarkdownOrderedListNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let contentBuilder: MarkdownContentBuilder

  public init(contentBuilder: MarkdownContentBuilder = MarkdownContentBuilder()) {
    self.contentBuilder = contentBuilder
  }

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

    // Parse digits
    var digits = ""
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .characters,
          Int(tok.text) != nil {
      digits.append(tok.text)
      current += 1
    }
    guard !digits.isEmpty else { return false }

    // Expect '.' or ')'
    guard current < context.tokens.count,
          let punct = context.tokens[current] as? MarkdownToken,
          punct.element == .punctuation,
          punct.text == "." || punct.text == ")" else { return false }
    current += 1

    // Require space
    guard current < context.tokens.count,
          let space = context.tokens[current] as? MarkdownToken,
          space.element == .whitespaces else { return false }
    current += 1

    // Capture content
    let contentStart = current
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element != .newline, tok.element != .hardbreak, tok.element != .eof {
      current += 1
    }
    let contentEnd = current

    let startNum = Int(digits) ?? 1
    let list = OrderedListNode(start: startNum)
    let item = ListItemNode(marker: digits)
    if contentEnd > contentStart {
      let startTok = context.tokens[contentStart] as! MarkdownToken
      let endTok = context.tokens[contentEnd - 1] as! MarkdownToken
      let range = startTok.range.lowerBound..<endTok.range.upperBound
      let para = ParagraphNode(range: range)

      let inlineTokens = Array(context.tokens[contentStart..<contentEnd])
      var inlineContext = CodeConstructContext(current: para, tokens: inlineTokens, state: context.state)
      _ = contentBuilder.build(from: &inlineContext)
      context.errors.append(contentsOf: inlineContext.errors)

      item.append(para)
    }
    list.append(item)
    context.current.append(list)
    context.consuming = current
    return true
  }
}


import CodeParserCore
import Foundation

/// Builder for Markdown block quotes, lines beginning with `>`.
/// This implementation creates a `BlockquoteNode` containing a single
/// paragraph node for the line content.
public struct MarkdownBlockquoteNodeBuilder: CodeNodeBuilder {
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
    // Skip initial spaces
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .whitespaces {
      current += 1
    }

    guard current < context.tokens.count,
          let marker = context.tokens[current] as? MarkdownToken,
          marker.element == .punctuation, marker.text == ">" else { return false }
    current += 1

    // Skip one optional space after '>'
    if current < context.tokens.count,
       let space = context.tokens[current] as? MarkdownToken,
       space.element == .whitespaces {
      current += 1
    }

    // Capture remainder of line as paragraph content
    let contentStart = current
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element != .newline, tok.element != .hardbreak, tok.element != .eof {
      current += 1
    }
    let contentEnd = current

    let bqNode = BlockquoteNode()
    if contentEnd > contentStart {
      // Build paragraph node for content
      let startToken = context.tokens[contentStart] as! MarkdownToken
      let endToken = context.tokens[contentEnd - 1] as! MarkdownToken
      let range = startToken.range.lowerBound..<endToken.range.upperBound
      let para = ParagraphNode(range: range)

      let inlineTokens = Array(context.tokens[contentStart..<contentEnd])
      var inlineContext = CodeConstructContext(current: para, tokens: inlineTokens, state: context.state)
      _ = contentBuilder.build(from: &inlineContext)
      context.errors.append(contentsOf: inlineContext.errors)

      bqNode.append(para)
    }
    context.current.append(bqNode)
    context.consuming = current
    return true
  }
}


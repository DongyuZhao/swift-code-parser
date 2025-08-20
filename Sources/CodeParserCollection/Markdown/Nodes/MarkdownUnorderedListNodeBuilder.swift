import CodeParserCore
import Foundation

/// Builder for unordered lists using `-`, `*`, or `+` markers.
/// Each invocation parses a single list item and wraps it in an
/// `UnorderedListNode` if necessary.
public struct MarkdownUnorderedListNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

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

    guard current < context.tokens.count,
          let marker = context.tokens[current] as? MarkdownToken,
          marker.element == .punctuation,
          ["-", "*", "+"].contains(marker.text) else { return false }
    current += 1

    // Following space required
    guard current < context.tokens.count,
          let space = context.tokens[current] as? MarkdownToken,
          space.element == .whitespaces else { return false }
    current += 1

    let contentStart = current
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element != .newline, tok.element != .hardbreak, tok.element != .eof {
      current += 1
    }
    let contentEnd = current

    let list = UnorderedListNode()
    let item = ListItemNode(marker: marker.text)
    if contentEnd > contentStart {
      let startTok = context.tokens[contentStart] as! MarkdownToken
      let endTok = context.tokens[contentEnd - 1] as! MarkdownToken
      let range = startTok.range.lowerBound..<endTok.range.upperBound
      let para = ParagraphNode(range: range)
      item.append(para)
    }
    list.append(item)
    context.current.append(list)
    context.consuming = current
    return true
  }
}


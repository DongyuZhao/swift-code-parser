import CodeParserCore
import Foundation

/// Parses setext-style headings (e.g. "Heading\n===").
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }

    // Require start of line
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    var lines: [[any CodeToken<MarkdownTokenElement>]] = []
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    var current: [any CodeToken<MarkdownTokenElement>] = []

    while idx < tokens.count {
      let tok = tokens[idx]
      if tok.element == .newline {
        // blank line not allowed in heading content
        if current.allSatisfy({ $0.element == .space || $0.element == .tab }) { return false }
        var line = current
        guard trimLine(&line) else { return false }
        lines.append(line)
        contentTokens.append(contentsOf: line)
        idx += 1 // consume newline
        contentTokens.append(tok) // preserve newline between lines for inline parsing
        if let (level, endIdx) = Self.underline(tokens: tokens, start: idx) {
          // remove trailing newline token
          if contentTokens.last?.element == .newline { contentTokens.removeLast() }
          let node = HeaderNode(level: level)
          var children = MarkdownInlineParser.parse(contentTokens)
          // remove extraneous newline text nodes between lines and split nodes containing newlines
          var processed: [MarkdownNodeBase] = []
          for child in children {
            if let t = child as? TextNode, t.content.contains("\n") {
              let parts = t.content.split(separator: "\n", omittingEmptySubsequences: false)
              for (i, part) in parts.enumerated() {
                processed.append(TextNode(content: String(part)))
                if i < parts.count - 1 {
                  processed.append(LineBreakNode())
                }
              }
            } else if let t = child as? TextNode, t.content == "\n" {
              processed.append(LineBreakNode())
            } else {
              processed.append(child as! MarkdownNodeBase)
            }
          }
          for c in processed { node.append(c) }
          context.current.append(node)
          context.consuming = endIdx
          if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
          return true
        }
        current = []
        continue
      } else if tok.element == .eof {
        return false
      } else {
        current.append(tok)
        idx += 1
      }
    }
    return false
  }

  /// Trim up to 3 leading spaces and any trailing spaces/tabs. Returns false if
  /// more than 3 leading spaces are present.
  private func trimLine(_ tokens: inout [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var removed = 0
    while removed < 3, let first = tokens.first {
      if first.element == .space {
        tokens.removeFirst()
        removed += 1
      } else if first.element == .tab {
        let step = 4 - (removed % 4)
        if removed + step > 3 { break }
        tokens.removeFirst()
        removed += step
      } else {
        break
      }
    }
    if let first = tokens.first, first.element == .space || first.element == .tab {
      return false
    }
    while let last = tokens.last, last.element == .space || last.element == .tab {
      tokens.removeLast()
    }
    return true
  }

  /// Determine if a setext underline starts at `start` in the token stream.
  /// Returns the heading level and the index after the underline line if found.
  static func underline(tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> (level: Int, end: Int)? {
    var idx = start
    let (spaces, afterIndent) = consumeIndentation(tokens, start: idx)
    if spaces > 3 { return nil }
    idx = afterIndent
    guard idx < tokens.count else { return nil }
    let first = tokens[idx]
    guard first.element == .equals || first.element == .dash else { return nil }
    let marker = first.element
    idx += 1
    while idx < tokens.count, tokens[idx].element == marker { idx += 1 }
    while idx < tokens.count, tokens[idx].element == .space || tokens[idx].element == .tab { idx += 1 }
    guard idx < tokens.count else { return nil }
    if tokens[idx].element == .newline {
      return (marker == .equals ? 1 : 2, idx + 1)
    } else if tokens[idx].element == .eof {
      return (marker == .equals ? 1 : 2, idx)
    } else {
      return nil
    }
  }

  /// Helper for paragraph builder to detect underline without consuming.
  static func isUnderline(tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> Bool {
    underline(tokens: tokens, start: start) != nil
  }
}

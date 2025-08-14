import CodeParserCore
import Foundation

/// Parses paragraph blocks made of consecutive text lines.
public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }
    let first = tokens[idx]
    if first.element == .newline || first.element == .eof { return false }

    var lines: [[any CodeToken<MarkdownTokenElement>]] = []
    var current: [any CodeToken<MarkdownTokenElement>] = []

    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == .newline {
        // End of line
        if current.allSatisfy({ $0.element == .space || $0.element == .tab }) {
          idx += 1
          if let state = context.state as? MarkdownConstructState {
            state.previousLineBlank = true
          }
          break
        }
        lines.append(current)
        current = []
        if let state = context.state as? MarkdownConstructState {
          state.previousLineBlank = false
        }
        let nextStart = idx + 1
        if isParagraphContinuation(tokens: tokens, start: nextStart, state: context.state as? MarkdownConstructState) {
          idx = nextStart
          continue
        } else {
          idx = nextStart
          break
        }
      } else if t.element == .eof {
        if !current.isEmpty {
          lines.append(current)
          if let state = context.state as? MarkdownConstructState {
            state.previousLineBlank = false
          }
        }
        break
      } else {
        current.append(t)
        idx += 1
      }
    }

    if lines.isEmpty { // no non-blank content
      return false
    }

    // Prepare lines with trimmed indentation
    var processed: [[any CodeToken<MarkdownTokenElement>]] = []
    for var line in lines {
      _ = trimLine(&line)
      processed.append(line)
    }

    if !processed.isEmpty {
      var last = processed.removeLast()
      while let t = last.last, t.element == .space { last.removeLast() }
      processed.append(last)
    }

    // Combine lines back together using explicit newline tokens so that
    // inline parsing can handle constructs (like code spans) that cross
    // line boundaries.
    var combined: [any CodeToken<MarkdownTokenElement>] = []
    let dummy = ""
    for i in 0..<processed.count {
      combined.append(contentsOf: processed[i])
      if i < processed.count - 1 {
        combined.append(MarkdownToken.newline(at: dummy.startIndex..<dummy.startIndex))
      }
    }

    let node = ParagraphNode(range: dummy.startIndex..<dummy.startIndex)
    for child in MarkdownInlineParser.parse(combined) {
      node.append(child)
    }
    context.current.append(node)
    context.consuming = idx
    return true
  }

  private func isParagraphContinuation(tokens: [any CodeToken<MarkdownTokenElement>], start: Int, state: MarkdownConstructState?) -> Bool {
    var idx = start
    // Skip spaces/tabs
    let (spaces, after) = consumeIndentation(tokens, start: idx)
    idx = after
    if idx >= tokens.count { return false }
    let tok = tokens[idx]
    if tok.element == .newline { return false } // blank line
    // Heading start
    if tok.element == .hash && spaces <= 3 { return false }
    // Setext underline for previous line
    if MarkdownSetextHeadingBuilder.isUnderline(tokens: tokens, start: start) { return false }
    // Blockquote start
    if tok.element == .gt && spaces <= 3 { return false }
    // Unordered list start or line beginning with '*'
    if (tok.element == .dash || tok.element == .plus || tok.element == .asterisk), spaces <= 3 {
      if idx + 1 < tokens.count,
         (tokens[idx + 1].element == .space || tokens[idx + 1].element == .tab) {
        return false
      }
      if tok.element == .asterisk { return false }
    }
    // Fenced code block start
    if spaces <= 3, tok.element == .backtick || tok.element == .tilde {
      var fenceLen = 0
      var j = idx
      while j < tokens.count, tokens[j].text == tok.text {
        fenceLen += 1
        j += 1
      }
      if fenceLen >= 3 { return false }
    }
    // Thematic break
    if MarkdownThematicBreakBuilder.isThematicBreak(tokens: tokens, start: start) { return false }
    // Indented code block
    if spaces >= 4 && (state?.previousLineBlank ?? true) { return false }
    return true
  }

  private func trimLine(_ tokens: inout [any CodeToken<MarkdownTokenElement>]) -> Int {
    var removed = 0
    while removed < 4, let first = tokens.first {
      if first.element == .space {
        tokens.removeFirst()
        removed += 1
      } else if first.element == .tab {
        let step = 4 - (removed % 4)
        tokens.removeFirst()
        removed += step
      } else {
        break
      }
    }
    return removed
  }
}

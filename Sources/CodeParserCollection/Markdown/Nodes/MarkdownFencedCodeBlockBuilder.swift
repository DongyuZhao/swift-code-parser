import CodeParserCore
import Foundation

/// Parses fenced code blocks using backtick (```) or tilde (~~~) fences as
/// specified by CommonMark. Handles indentation, info strings and optional
/// language identifiers.
public class MarkdownFencedCodeBlockBuilder: CodeNodeBuilder {
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

    // Leading indentation up to three spaces
    let (indent, afterIndent) = consumeIndentation(tokens, start: idx)
    if indent >= 4 { return false }
    idx = afterIndent

    // Opening fence character (` or ~)
    guard idx < tokens.count,
      tokens[idx].element == .backtick || tokens[idx].element == .tilde
    else { return false }
    let fenceChar = tokens[idx].text

    // Length of fence sequence
    var fenceLen = 0
    while idx < tokens.count, tokens[idx].text == fenceChar {
      fenceLen += 1
      idx += 1
    }
    if fenceLen < 3 { return false }

    // Collect info string until newline
    var infoTokens: [any CodeToken<MarkdownTokenElement>] = []
    var containsBacktick = false
    while idx < tokens.count, tokens[idx].element != .newline {
      if tokens[idx].element == .backtick { containsBacktick = true }
      infoTokens.append(tokens[idx])
      idx += 1
    }

    // Backtick fences disallow backticks in the info string
    if fenceChar == "`" && containsBacktick { return false }
    if idx >= tokens.count || tokens[idx].element != .newline { return false }
    idx += 1 // consume newline

    // Gather content lines until closing fence or EOF
    var lines: [String] = []
    var hadTrailingNewline = false
    while idx < tokens.count, tokens[idx].element != .eof {
      // Detect closing fence
      var j = idx
      let (leading, afterLeading) = consumeIndentation(tokens, start: j)
      j = afterLeading
      var closeLen = 0
      while j < tokens.count, tokens[j].text == fenceChar {
        closeLen += 1
        j += 1
      }
      if leading <= 3, closeLen >= fenceLen {
        var k = j
        let (_, afterTrail) = consumeIndentation(tokens, start: k)
        k = afterTrail
        if k == tokens.count || tokens[k].element == .newline {
          idx = k
          if idx < tokens.count, tokens[idx].element == .newline {
            idx += 1
          }
          hadTrailingNewline = false
          break
        }
      }

      // Not a closing fence: capture line
      var lineStart = idx
      var removed = 0
      while removed < indent, lineStart < tokens.count {
        let t = tokens[lineStart]
        if t.element == .space {
          removed += 1
          lineStart += 1
        } else if t.element == .tab {
          let step = 4 - (removed % 4)
          removed += step
          lineStart += 1
        } else {
          break
        }
      }
      var lineEnd = lineStart
      while lineEnd < tokens.count,
        tokens[lineEnd].element != .newline,
        tokens[lineEnd].element != .eof {
        lineEnd += 1
      }
      let line = tokens[lineStart..<lineEnd].map { $0.text }.joined()
      lines.append(line)
      idx = lineEnd
      if idx < tokens.count, tokens[idx].element == .newline {
        hadTrailingNewline = true
        idx += 1
      } else {
        hadTrailingNewline = false
      }
    }
    while lines.last == "" { lines.removeLast(); hadTrailingNewline = false }
    var code = lines.joined(separator: "\n")
    if hadTrailingNewline, let last = lines.last, !last.contains(fenceChar) {
      code.append("\n")
    }
    let info = infoTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
    let language = info.split(whereSeparator: { $0 == " " || $0 == "\t" }).first
      .flatMap { $0.isEmpty ? nil : String($0) }
    let node = CodeBlockNode(source: code, language: language)
    context.current.append(node)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }
}

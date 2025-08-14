import CodeParserCore
import Foundation

/// Parses block quotes prefixed with `>` and supports lazy continuation lines.
/// Lines are collected, stripped of the `>` marker, then parsed as their own
/// Markdown document so nested structures like headings or lists are handled
/// by existing builders.
public class MarkdownBlockquoteBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    // Detect initial quote marker with up to three leading spaces
    let (spaces, afterIndent) = consumeIndentation(tokens, start: idx)
    if spaces > 3 { return false }
    var i = afterIndent
    guard i < tokens.count, tokens[i].element == .gt else { return false }
    i += 1
    if i < tokens.count, tokens[i].element == .space || tokens[i].element == .tab { i += 1 }
    idx = i

    // Collect inner content tokens stripping leading markers
    var content = ""
    var lastLineBlank = false
    while idx < tokens.count {
      let lineStart = idx
      var i = idx
      let (lspaces, afterSpaces) = consumeIndentation(tokens, start: i)
      i = afterSpaces
      var isQuoted = false
      if lspaces <= 3, i < tokens.count, tokens[i].element == .gt {
        isQuoted = true
        i += 1
        if i < tokens.count, tokens[i].element == .space || tokens[i].element == .tab { i += 1 }
      }

      var j = isQuoted ? i : lineStart
      var lineIsBlank = true
      while j < tokens.count,
        tokens[j].element != .newline,
        tokens[j].element != .eof {
        if tokens[j].element != .space && tokens[j].element != .tab { lineIsBlank = false }
        j += 1
      }

      // Determine if unquoted line should end the block quote
      if !isQuoted {
        if lineIsBlank {
          if content.hasSuffix("\n") { content.removeLast() }
          break
        }
        // A blank line followed by an unquoted line terminates the quote.
        if lastLineBlank { break }
        // Lines starting block-level constructs should not be treated as lazy continuation.
        let look = afterSpaces
        if MarkdownThematicBreakBuilder.isThematicBreak(tokens: tokens, start: look) {
          break
        }
        if look < tokens.count {
          let t = tokens[look]
          if (t.element == .dash || t.element == .asterisk || t.element == .plus),
            look + 1 < tokens.count,
            (tokens[look + 1].element == .space || tokens[look + 1].element == .tab) {
            break
          }
          if t.element == .hash { break }
          if t.element == .number {
            var n = look
            while n < tokens.count, tokens[n].element == .number { n += 1 }
            if n < tokens.count, tokens[n].element == .dot,
              n + 1 < tokens.count,
              (tokens[n + 1].element == .space || tokens[n + 1].element == .tab) {
              break
            }
          }
        }
      }

      // Append line content
      let startContent = isQuoted ? i : lineStart
      for k in startContent..<j { content.append(tokens[k].text) }
      if j < tokens.count, tokens[j].element == .newline {
        content.append("\n")
        idx = j + 1
      } else {
        idx = j
      }
      lastLineBlank = lineIsBlank
    }

    if !content.isEmpty && !content.hasSuffix("\n") {
      content.append("\n")
    }
    let parser = CodeParser<MarkdownNodeElement, MarkdownTokenElement>(language: MarkdownLanguage())
    let result = parser.parse(content, language: MarkdownLanguage())

    let quote = BlockquoteNode()
    for child in result.root.children {
      if let child = child as? MarkdownNodeBase { quote.append(child) }
    }
    context.current.append(quote)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }
}

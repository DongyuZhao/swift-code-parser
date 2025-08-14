import CodeParserCore
import Foundation

/// Parses indented code blocks whose lines begin with four or more spaces.
///
/// The block may start without a blank line provided the previous parsed block
/// is not a paragraph. Within the block, exactly four spaces of indentation are
/// removed from each line while any additional spaces are preserved. Leading and
/// trailing blank lines (after the four-space baseline is removed) are trimmed
/// from the final result.
public class MarkdownIndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    guard let state = context.state as? MarkdownConstructState else { return false }

    // An indented code block cannot interrupt a paragraph
    if !state.previousLineBlank, context.current.children.last is ParagraphNode { return false }

    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }

    // Require start of line
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    // Initial indentation must be at least four spaces (tabs expand to four
    // column boundaries)
    let (spaces, firstIdx) = consumeIndentation(tokens, start: idx)
    if spaces < 4 { return false }
    idx = firstIdx

    var lines: [String] = []

    // Read the first line after removing exactly four spaces
    var current = String(repeating: " ", count: spaces - 4)
    while idx < tokens.count, tokens[idx].element != .newline, tokens[idx].element != .eof {
      current.append(tokens[idx].text)
      idx += 1
    }
    lines.append(current)
    if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }

    // Read subsequent lines
    while idx < tokens.count {
      var look = idx
      let (lineSpaces, afterIndent) = consumeIndentation(tokens, start: look)
      look = afterIndent
      if look >= tokens.count { idx = look; break }
      let next = tokens[look]
      if next.element == .newline {
        // blank line within code block, preserve indentation beyond baseline
        let blanks = String(repeating: " ", count: max(0, lineSpaces - 4))
        lines.append(blanks)
        idx = look + 1
        continue
      }
      if lineSpaces >= 4 {
        var line = String(repeating: " ", count: lineSpaces - 4)
        var j = look
        while j < tokens.count, tokens[j].element != .newline, tokens[j].element != .eof {
          line.append(tokens[j].text)
          j += 1
        }
        lines.append(line)
        idx = j
        if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }
        continue
      }
      break
    }

    // Trim leading and trailing blank lines
    while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
      lines.removeFirst()
    }
    while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
      lines.removeLast()
    }

    let node = CodeBlockNode(source: lines.joined(separator: "\n"))
    context.current.append(node)
    context.consuming = idx
    state.previousLineBlank = false
    return true
  }
}

import CodeParserCore
import Foundation

/// Parses unordered lists whose items may contain multiple block elements.
/// Markers supported are `-`, `*`, and `+` with up to three leading spaces.
public class MarkdownUnorderedListBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    var items: [ListItemNode] = []
    while idx < tokens.count {
      var lineStart = idx
      let (indent, afterIndent) = consumeIndentation(tokens, start: lineStart)
      lineStart = afterIndent
      if indent > 3 { break }
      guard lineStart < tokens.count else { break }
      let markerTok = tokens[lineStart]
      guard markerTok.element == .dash || markerTok.element == .asterisk || markerTok.element == .plus else { break }
      lineStart += 1

      // collect spaces/tabs after marker, allowing empty items
      let (spacesAfter, afterMarker) = consumeIndentation(tokens, start: lineStart, column: indent + 1)
      lineStart = afterMarker
      if spacesAfter == 0 {
        // newline must directly follow to form an empty item
        guard lineStart < tokens.count, tokens[lineStart].element == .newline || tokens[lineStart].element == .eof else { break }
      }
      let contentIndent = indent + 1 + max(1, spacesAfter)

      // first line content
      var firstLine = ""
      while lineStart < tokens.count,
            tokens[lineStart].element != .newline,
            tokens[lineStart].element != .eof {
        firstLine.append(tokens[lineStart].text)
        lineStart += 1
      }
      var lines = [firstLine]
      if lineStart < tokens.count, tokens[lineStart].element == .newline {
        idx = lineStart + 1
      } else {
        idx = lineStart
      }

      // collect continuation lines
      while idx < tokens.count {
        var look = idx
        let (lspaces, afterLook) = consumeIndentation(tokens, start: look)
        look = afterLook
        if look >= tokens.count { idx = look; break }
        let next = tokens[look]
        if next.element == .newline {
          lines.append("")
          idx = look + 1
          continue
        }
        if lspaces >= contentIndent {
          var line = String(repeating: " ", count: lspaces - contentIndent)
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
        if lspaces > indent {
          var line = String(repeating: " ", count: lspaces - indent)
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
        // start of next list item?
        if lspaces <= indent + 3 {
          let tok = tokens[look]
          if tok.element == .dash || tok.element == .asterisk || tok.element == .plus {
            if look + 1 < tokens.count,
               (tokens[look + 1].element == .space || tokens[look + 1].element == .tab) {
              break
            }
          }
          if tok.element == .number {
            var n = look
            while n < tokens.count, tokens[n].element == .number { n += 1 }
            if n < tokens.count, tokens[n].element == .dot,
               n + 1 < tokens.count,
               (tokens[n + 1].element == .space || tokens[n + 1].element == .tab) {
              break
            }
          }
        }
        break
      }

      // trim trailing blank lines
      while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
        lines.removeLast()
      }

      let content = lines.joined(separator: "\n") + "\n"
      let parser = CodeParser<MarkdownNodeElement, MarkdownTokenElement>(language: MarkdownLanguage())
      let result = parser.parse(content, language: MarkdownLanguage())
      let li = ListItemNode(marker: markerTok.text)
      for child in result.root.children {
        if let list = child as? ListNode { list.level += 1 }
        if let m = child as? MarkdownNodeBase { li.append(m) }
      }
      items.append(li)

      // prepare for next potential item
      if idx >= tokens.count || tokens[idx].element == .eof { break }
      if tokens[idx].element != .newline { break }
      idx += 1
    }

    if items.isEmpty { return false }
    let list = UnorderedListNode(level: 1)
    for li in items { list.append(li) }
    context.current.append(list)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }
}

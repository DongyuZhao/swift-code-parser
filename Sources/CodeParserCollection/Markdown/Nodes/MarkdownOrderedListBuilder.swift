import CodeParserCore
import Foundation

/// Parses ordered lists using numeric markers like `1.` with up to three leading spaces.
/// List items may contain multiple block elements.
public class MarkdownOrderedListBuilder: CodeNodeBuilder {
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
    var startNumber = 1
    while idx < tokens.count {
      var lineStart = idx
      let (indent, afterIndent) = consumeIndentation(tokens, start: lineStart)
      lineStart = afterIndent
      if indent > 3 { break }
      guard lineStart < tokens.count, tokens[lineStart].element == .number else { break }
      var numStr = ""
      while lineStart < tokens.count, tokens[lineStart].element == .number {
        numStr.append(tokens[lineStart].text)
        lineStart += 1
      }
      guard lineStart < tokens.count, tokens[lineStart].element == .dot else { break }
      lineStart += 1

      // determine start number from first item
      if items.isEmpty, let n = Int(numStr) { startNumber = n }

      // collect spaces/tabs after marker, allowing empty items
      let markerColumn = indent + numStr.count + 1
      let (spacesAfter, afterMarker) = consumeIndentation(tokens, start: lineStart, column: markerColumn)
      lineStart = afterMarker
      if spacesAfter == 0 {
        guard lineStart < tokens.count, tokens[lineStart].element == .newline || tokens[lineStart].element == .eof else { break }
      }
      let contentIndent = indent + numStr.count + 1 + max(1, spacesAfter)

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

      while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
        lines.removeLast()
      }

      let content = lines.joined(separator: "\n") + "\n"
      let parser = CodeParser<MarkdownNodeElement, MarkdownTokenElement>(language: MarkdownLanguage())
      let result = parser.parse(content, language: MarkdownLanguage())
      let li = ListItemNode(marker: numStr + ".")
      for child in result.root.children {
        if let list = child as? ListNode { list.level += 1 }
        if let m = child as? MarkdownNodeBase { li.append(m) }
      }
      items.append(li)

      if idx >= tokens.count || tokens[idx].element == .eof { break }
      if tokens[idx].element != .newline { break }
      idx += 1
    }

    if items.isEmpty { return false }
    let list = OrderedListNode(start: startNumber, level: 1)
    for li in items { list.append(li) }
    context.current.append(list)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }
}

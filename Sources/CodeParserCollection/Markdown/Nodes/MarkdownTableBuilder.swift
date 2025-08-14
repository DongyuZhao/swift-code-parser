import CodeParserCore
import Foundation

/// Parses GFM tables with header, alignment row, and optional body rows.
public class MarkdownTableBuilder: CodeNodeBuilder {
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

    // Capture header line
    let headerStart = idx
    var headerEnd = idx
    var sawPipe = false
    while headerEnd < tokens.count {
      let t = tokens[headerEnd]
      if t.element == .newline || t.element == .eof { break }
      if t.element == .pipe { sawPipe = true }
      headerEnd += 1
    }
    if !sawPipe { return false }
    if headerEnd >= tokens.count || tokens[headerEnd].element != .newline { return false }
    let headerLine = Array(tokens[headerStart..<headerEnd])

    // Separator line
    var sepStart = headerEnd + 1
    if sepStart >= tokens.count { return false }
    var sepEnd = sepStart
    var nonWhitespace = false
    while sepEnd < tokens.count {
      let t = tokens[sepEnd]
      if t.element == .newline || t.element == .eof { break }
      if t.element != .space && t.element != .tab { nonWhitespace = true }
      sepEnd += 1
    }
    if !nonWhitespace { return false }
    if sepEnd >= tokens.count || tokens[sepEnd].element != .newline { return false }
    let sepLine = Array(tokens[sepStart..<sepEnd])

    // Split header and separator
    var headerCells = splitRow(headerLine)
    var sepCells = splitRow(sepLine)
    trimEdgeEmpty(&headerCells)
    trimEdgeEmpty(&sepCells)
    // Parse alignments
    var alignments: [TableCellNode.Alignment] = []
    for cell in sepCells {
      let trimmed = trimSpaces(cell)
      if trimmed.isEmpty { return false }
      var hasDash = false
      for tok in trimmed {
        if tok.element == .dash {
          hasDash = true
        } else if tok.element != .colon {
          return false
        }
      }
      if !hasDash { return false }
      let startsColon = trimmed.first?.element == .colon
      let endsColon = trimmed.last?.element == .colon
      if startsColon && endsColon {
        alignments.append(.center)
      } else if startsColon {
        alignments.append(.left)
      } else if endsColon {
        alignments.append(.right)
      } else {
        alignments.append(.none)
      }
    }
    if alignments.count != headerCells.count { return false }

    // Build header node
    let dummy = ""
    let table = TableNode(range: dummy.startIndex..<dummy.startIndex)
    let headerNode = TableHeaderNode(range: dummy.startIndex..<dummy.startIndex)
    let headerRow = TableRowNode(range: dummy.startIndex..<dummy.startIndex, isHeader: true)
    for i in 0..<headerCells.count {
      var cellTokens = trimSpaces(headerCells[i])
      let cellNode = TableCellNode(range: dummy.startIndex..<dummy.startIndex, alignment: alignments[i])
      for child in MarkdownInlineParser.parse(cellTokens) {
        cellNode.append(child)
      }
      headerRow.append(cellNode)
    }
    headerNode.append(headerRow)
    table.append(headerNode)

    // Parse body rows
    idx = sepEnd + 1 // move past newline after separator
    var contentNode: TableContentNode? = nil
    while idx < tokens.count && isTableContinuation(tokens: tokens, start: idx) {
      var rowEnd = idx
      while rowEnd < tokens.count {
        let t = tokens[rowEnd]
        if t.element == .newline || t.element == .eof { break }
        rowEnd += 1
      }
      let rowTokens = Array(tokens[idx..<rowEnd])
      var cells = splitRow(rowTokens)
      trimEdgeEmpty(&cells)
      if cells.count < alignments.count {
        cells.append(contentsOf: Array(repeating: [], count: alignments.count - cells.count))
      } else if cells.count > alignments.count {
        cells = Array(cells.prefix(alignments.count))
      }
      let rowNode = TableRowNode(range: dummy.startIndex..<dummy.startIndex)
      for i in 0..<alignments.count {
        var cellToks = trimSpaces(cells[i])
        let cellNode = TableCellNode(range: dummy.startIndex..<dummy.startIndex, alignment: alignments[i])
        for child in MarkdownInlineParser.parse(cellToks) {
          cellNode.append(child)
        }
        rowNode.append(cellNode)
      }
      if contentNode == nil { contentNode = TableContentNode(range: dummy.startIndex..<dummy.startIndex) }
      contentNode!.append(rowNode)
      idx = rowEnd
      if idx < tokens.count && tokens[idx].element == .newline { idx += 1 }
    }
    if let content = contentNode {
      table.append(content)
    }
    context.current.append(table)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }

  // Split a row into cell token arrays respecting escapes and code spans
  private func splitRow(_ row: [any CodeToken<MarkdownTokenElement>]) -> [[any CodeToken<MarkdownTokenElement>]] {
    var cells: [[any CodeToken<MarkdownTokenElement>]] = []
    var current: [any CodeToken<MarkdownTokenElement>] = []
    var i = 0
    var openBackticks: Int? = nil
    while i < row.count {
      let tok = row[i]
      if tok.element == .backtick {
        var run = 0
        var j = i
        while j < row.count && row[j].element == .backtick {
          current.append(row[j])
          run += 1
          j += 1
        }
        if openBackticks == nil {
          openBackticks = run
        } else if openBackticks == run {
          openBackticks = nil
        }
        i = j
        continue
      }
      if tok.element == .pipe && openBackticks == nil && current.last?.element != .backslash {
        cells.append(current)
        current = []
      } else {
        current.append(tok)
      }
      i += 1
    }
    cells.append(current)
    return cells
  }

  private func trimEdgeEmpty(_ cells: inout [[any CodeToken<MarkdownTokenElement>]]) {
    if let first = cells.first, first.isEmpty { cells.removeFirst() }
    if let last = cells.last, last.isEmpty { cells.removeLast() }
  }

  private func trimSpaces(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [any CodeToken<MarkdownTokenElement>] {
    var toks = tokens
    while let first = toks.first, first.element == .space { toks.removeFirst() }
    while let last = toks.last, last.element == .space { toks.removeLast() }
    return toks
  }

  private func isTableContinuation(tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> Bool {
    var idx = start
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .space {
      spaces += 1
      idx += 1
    }
    if idx >= tokens.count { return false }
    let tok = tokens[idx]
    if tok.element == .newline || tok.element == .eof { return false }
    if tok.element == .gt && spaces <= 3 { return false }
    if tok.element == .hash && spaces <= 3 { return false }
    if (tok.element == .dash || tok.element == .asterisk || tok.element == .plus) && spaces <= 3 {
      if idx + 1 < tokens.count, tokens[idx + 1].element == .space { return false }
    }
    if tok.element == .number && spaces <= 3 {
      var j = idx
      while j < tokens.count, tokens[j].element == .number { j += 1 }
      if j < tokens.count, tokens[j].element == .dot, j + 1 < tokens.count, tokens[j + 1].element == .space {
        return false
      }
    }
    if spaces <= 3, (tok.element == .backtick || tok.element == .tilde) {
      var fenceLen = 0
      var j = idx
      while j < tokens.count, tokens[j].text == tok.text {
        fenceLen += 1
        j += 1
      }
      if fenceLen >= 3 { return false }
    }
    if MarkdownThematicBreakBuilder.isThematicBreak(tokens: tokens, start: start) { return false }
    return true
  }
}


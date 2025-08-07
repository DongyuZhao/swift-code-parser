import CodeParserCore
import Foundation

public class MarkdownTableBuilder: CodeNodeBuilder {
  private var columnAlignments: [TableCellNode.Alignment] = []
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let first = context.tokens[context.consuming] as? MarkdownToken,
      first.element == .pipe
    else { return false }

    // Pre-scan to ensure this is a valid GFM table: need a header row then a separator row
    let original = context.consuming
    var scanIdx = original
    var firstLine: [MarkdownToken] = []
    while scanIdx < context.tokens.count, let tok = context.tokens[scanIdx] as? MarkdownToken {
      if tok.element == .newline { scanIdx += 1; break }
      firstLine.append(tok); scanIdx += 1
    }
    // Collect second line tokens
    var secondLine: [MarkdownToken] = []
    while scanIdx < context.tokens.count, let tok = context.tokens[scanIdx] as? MarkdownToken {
      if tok.element == .newline { break }
      secondLine.append(tok); scanIdx += 1
    }
    // Must have a potential separator line per GFM: only pipes, colons, dashes, spaces and at least one dash
    let isSeparatorLine = !secondLine.isEmpty && secondLine.allSatisfy { t in
      let trimmed = t.text.trimmingCharacters(in: .whitespaces)
      return t.element == .pipe || t.element == .space || trimmed.isEmpty || trimmed.allSatisfy { ch in ch == "-" || ch == ":" }
    } && secondLine.contains(where: { $0.text.contains("-") })
    if !isSeparatorLine { return false }

    // Derive column alignments from the separator line now
    var processedSep = secondLine.filter { $0.element != .eof }
    if let first = processedSep.first, first.element == .pipe { processedSep.removeFirst() }
    if let last = processedSep.last, last.element == .pipe { processedSep.removeLast() }
    var segments: [[MarkdownToken]] = [[]]
    for tok in processedSep {
      if tok.element == .pipe {
        segments.append([])
      } else {
        segments[segments.count - 1].append(tok)
      }
    }
    columnAlignments = segments.map { seg in
      let text = seg.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
      if text.hasPrefix(":") && text.hasSuffix(":") { return .center }
      if text.hasPrefix(":") { return .left }
      if text.hasSuffix(":") { return .right }
      return .none
    }
    // Reset to original for actual parsing
    context.consuming = original

  let table = TableNode(range: first.range)
    context.current.append(table)

    var isFirstRow = true
    var foundSeparator = false

    while true {
      guard
        parseRow(
          into: table, context: &context, isFirstRow: isFirstRow, foundSeparator: &foundSeparator)
      else { break }
      if context.consuming >= context.tokens.count { break }
      guard let next = context.tokens[context.consuming] as? MarkdownToken,
        next.element == .pipe
      else { break }
      isFirstRow = false
    }
    return true
  }

  private func parseRow(
    into table: TableNode,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
    isFirstRow: Bool, foundSeparator: inout Bool
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let start = context.tokens[context.consuming] as? MarkdownToken,
      start.element == .pipe
    else { return false }
    var rowTokens: [MarkdownToken] = []
    while context.consuming < context.tokens.count {
      guard let tok = context.tokens[context.consuming] as? MarkdownToken else { break }
      if tok.element == .newline { break }
      rowTokens.append(tok)
      context.consuming += 1
    }
    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }

    // Check if this is a separator row (contains only |, -, :, and spaces)
    let isSeparatorRow = rowTokens.allSatisfy { token in
      let text = token.text.trimmingCharacters(in: .whitespaces)
      return token.element == .pipe || token.element == .space || text.isEmpty
        || text.allSatisfy { char in char == "-" || char == ":" }
    }

  // Skip separator rows - they define table structure but aren't content
  if isSeparatorRow { foundSeparator = true; table.alignments = columnAlignments; return true }

    // Determine if this row is a header:
    // - First row is header if we haven't found separator yet
    // - OR if this is the first row and no separator exists
    let isHeader = isFirstRow && !foundSeparator

    let row = TableRowNode(range: start.range, isHeader: isHeader)
    var cellTokens: [MarkdownToken] = []

    // Remove leading and trailing pipes, and EOF tokens
    var processedTokens = rowTokens.filter { $0.element != .eof }
    if let first = processedTokens.first, first.element == .pipe {
      processedTokens.removeFirst()
    }
    if let last = processedTokens.last, last.element == .pipe {
      processedTokens.removeLast()
    }

    for tok in processedTokens {
      if tok.element == .pipe {
        // Escaped pipe: if previous token in cellTokens is a backslash, treat as literal
        if let last = cellTokens.last, last.element == .backslash {
          cellTokens.append(tok) // keep literal pipe in same cell
          continue
        }
        // Create cell from accumulated tokens (even if empty, to maintain column count)
  let alignment = columnAlignments.indices.contains(row.children.count) ? columnAlignments[row.children.count] : .none
  let cell = TableCellNode(range: start.range, alignment: alignment)

        // Trim leading and trailing whitespace tokens from cell content
        var trimmedCellTokens = cellTokens
        while let first = trimmedCellTokens.first, first.element == .space {
          trimmedCellTokens.removeFirst()
        }
        while let last = trimmedCellTokens.last, last.element == .space {
          trimmedCellTokens.removeLast()
        }

        var subCtx = CodeConstructContext(
          current: cell, tokens: trimmedCellTokens, state: context.state)
        let inlineBuilder = MarkdownInlineBuilder(stopAt: [])
        _ = inlineBuilder.build(from: &subCtx)
        row.append(cell)
        cellTokens.removeAll()
      } else {
        cellTokens.append(tok)
      }
    }

    // Process final cell if we have remaining tokens
  if !cellTokens.isEmpty {
  let alignment = columnAlignments.indices.contains(row.children.count) ? columnAlignments[row.children.count] : .none
  let cell = TableCellNode(range: start.range, alignment: alignment)

      // Trim leading and trailing whitespace tokens from cell content
      var trimmedCellTokens = cellTokens
      while let first = trimmedCellTokens.first, first.element == .space {
        trimmedCellTokens.removeFirst()
      }
      while let last = trimmedCellTokens.last, last.element == .space {
        trimmedCellTokens.removeLast()
      }

      var subCtx = CodeConstructContext(
        current: cell, tokens: trimmedCellTokens, state: context.state)
      let inlineBuilder = MarkdownInlineBuilder(stopAt: [])
      _ = inlineBuilder.build(from: &subCtx)
      row.append(cell)
    }
    table.append(row)
    return true
  }
}

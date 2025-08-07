import Foundation
import SwiftParser

public class MarkdownTableBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let first = context.tokens[context.consuming] as? MarkdownToken,
              first.element == .pipe else { return false }

        let table = TableNode(range: first.range)
        context.current.append(table)

        var isFirstRow = true
        var foundSeparator = false

        while true {
            guard parseRow(into: table, context: &context, isFirstRow: isFirstRow, foundSeparator: &foundSeparator) else { break }
            if context.consuming >= context.tokens.count { break }
            guard let next = context.tokens[context.consuming] as? MarkdownToken,
                  next.element == .pipe else { break }
            isFirstRow = false
        }
        return true
    }

    private func parseRow(into table: TableNode, context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>, isFirstRow: Bool, foundSeparator: inout Bool) -> Bool {
        guard context.consuming < context.tokens.count,
              let start = context.tokens[context.consuming] as? MarkdownToken,
              start.element == .pipe else { return false }
        var rowTokens: [MarkdownToken] = []
        while context.consuming < context.tokens.count {
            guard let tok = context.tokens[context.consuming] as? MarkdownToken else { break }
            if tok.element == .newline { break }
            rowTokens.append(tok)
            context.consuming += 1
        }
        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline { context.consuming += 1 }

        // Check if this is a separator row (contains only |, -, :, and spaces)
        let isSeparatorRow = rowTokens.allSatisfy { token in
            let text = token.text.trimmingCharacters(in: .whitespaces)
            return token.element == .pipe ||
                   token.element == .space ||
                   text.isEmpty ||
                   text.allSatisfy { char in char == "-" || char == ":" }
        }

        // Skip separator rows - they define table structure but aren't content
        if isSeparatorRow {
            foundSeparator = true
            return true  // Continue parsing but don't create a row node
        }

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
                // Create cell from accumulated tokens (even if empty, to maintain column count)
                let cell = TableCellNode(range: start.range)
                var subCtx = CodeConstructContext(current: cell, tokens: cellTokens, state: context.state)
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
            let cell = TableCellNode(range: start.range)
            var subCtx = CodeConstructContext(current: cell, tokens: cellTokens, state: context.state)
            let inlineBuilder = MarkdownInlineBuilder(stopAt: [])
            _ = inlineBuilder.build(from: &subCtx)
            row.append(cell)
        }
        table.append(row)
        return true
    }
}

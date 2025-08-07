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

        while true {
            guard parseRow(into: table, context: &context) else { break }
            if context.consuming >= context.tokens.count { break }
            guard let next = context.tokens[context.consuming] as? MarkdownToken,
                  next.element == .pipe else { break }
        }
        return true
    }

    private func parseRow(into table: TableNode, context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
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

        let row = TableRowNode(range: start.range)
        var cellTokens: [MarkdownToken] = []
        for tok in rowTokens + [MarkdownToken.pipe(at: start.range)] {
            if tok.element == .pipe {
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
        table.append(row)
        return true
    }
}

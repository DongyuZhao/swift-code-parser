import Foundation

extension MarkdownLanguage {
    public class TableBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .pipe = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev { return true }
            }
            return false
        }
        func parseRow(_ context: inout CodeContext) -> [String] {
            var cells: [String] = []
            var cell = ""
            context.index += 1 // skip leading pipe
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .pipe:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        cell = ""
                        context.index += 1
                    case .newline, .eof:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        if let last = cells.last, last.isEmpty { cells.removeLast() }
                        context.index += 1
                        return cells
                    default:
                        cell += tok.text
                        context.index += 1
                    }
                } else {
                    context.index += 1
                }
            }
            if !cell.isEmpty || !cells.isEmpty {
                cells.append(cell.trimmingCharacters(in: .whitespaces))
            }
            return cells
        }

        func parseDelimiter(_ context: inout CodeContext) -> [String]? {
            guard context.index < context.tokens.count,
                  let first = context.tokens[context.index] as? Token,
                  case .pipe = first else { return nil }
            var snapshot = context.snapshot()
            let cells = parseRow(&context)
            for cell in cells {
                var trimmed = cell.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(":") { trimmed.removeFirst() }
                if trimmed.hasSuffix(":") { trimmed.removeLast() }
                if trimmed.count < 3 { context.restore(snapshot); return nil }
                if !trimmed.allSatisfy({ $0 == "-" }) {
                    context.restore(snapshot); return nil
                }
            }
            return cells
        }

        public func build(context: inout CodeContext) {
            var ctx = context
            let header = parseRow(&ctx)
            let startIndex = ctx.index
            if let _ = parseDelimiter(&ctx) {
                var rows: [[String]] = []
                while ctx.index < ctx.tokens.count,
                      let tok = ctx.tokens[ctx.index] as? Token,
                      case .pipe = tok {
                    rows.append(parseRow(&ctx))
                }

                let table = MarkdownTableNode()
                let headerNode = MarkdownTableHeaderNode()
                for cell in header {
                    let cellNode = MarkdownTableCellNode()
                    cellNode.addChild(MarkdownTextNode(value: cell))
                    headerNode.addChild(cellNode)
                }
                table.addChild(headerNode)

                for row in rows {
                    let rowNode = MarkdownTableRowNode()
                    for cell in row {
                        let cellNode = MarkdownTableCellNode()
                        cellNode.addChild(MarkdownTextNode(value: cell))
                        rowNode.addChild(cellNode)
                    }
                    table.addChild(rowNode)
                }

                context = ctx
                context.currentNode.addChild(table)
            } else {
                context.index = startIndex
                context.currentNode.addChild(MarkdownTableNode(value: header.joined(separator: "|")))
            }
        }
    }

}

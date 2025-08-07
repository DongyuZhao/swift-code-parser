import Foundation
import CodeParser

public class MarkdownFormulaBlockBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .formulaBlock else { return false }
        context.consuming += 1
        let expr = trimFormula(token.text)
        let node = FormulaBlockNode(expression: expr)
        context.current.append(node)
        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }

    private func trimFormula(_ text: String) -> String {
        var t = text
        if t.hasPrefix("$$") { t.removeFirst(2) }
        if t.hasSuffix("$$") { t.removeLast(2) }
        if t.hasPrefix("\\[") { t.removeFirst(2) }
        if t.hasSuffix("\\]") { t.removeLast(2) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

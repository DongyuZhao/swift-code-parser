import Foundation
import SwiftParser

public class FormulaExpressionBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count else { return false }
        if let token = context.tokens[context.consuming] as? FormulaToken, token.element == .eof {
            return false
        }
        if let expr = FormulaParser.parseExpression(&context) {
            context.current.append(expr)
            return true
        }
        return false
    }
}

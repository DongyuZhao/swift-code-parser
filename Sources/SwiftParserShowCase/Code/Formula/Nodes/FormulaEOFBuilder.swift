import Foundation
import SwiftParser

/// Consumes trailing EOF tokens.
public class FormulaEOFBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? FormulaToken,
              token.element == .eof else { return false }
        context.consuming += 1
        return true
    }
}

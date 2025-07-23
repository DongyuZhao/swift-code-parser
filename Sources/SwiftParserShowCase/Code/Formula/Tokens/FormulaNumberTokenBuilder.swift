import Foundation
import SwiftParser

public class FormulaNumberTokenBuilder: CodeTokenBuilder {
    public typealias Token = FormulaTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<FormulaTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        var index = start
        var hasDigits = false

        while index < context.source.endIndex && context.source[index].isNumber {
            hasDigits = true
            index = context.source.index(after: index)
        }

        if index < context.source.endIndex && context.source[index] == "." {
            let dotIndex = index
            var next = context.source.index(after: dotIndex)
            var hasDecimal = false
            while next < context.source.endIndex && context.source[next].isNumber {
                hasDecimal = true
                next = context.source.index(after: next)
            }
            if hasDecimal {
                hasDigits = true
                index = next
            }
        }

        guard hasDigits else { return false }
        context.consuming = index
        let text = String(context.source[start..<index])
        context.tokens.append(FormulaToken.number(text, at: start..<index))
        return true
    }
}

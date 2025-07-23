import Foundation
import SwiftParser

public class FormulaNumberTokenBuilder: CodeTokenBuilder {
    public typealias Token = FormulaTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<FormulaTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        var index = start
        let char = context.source[index]
        guard char.isNumber else { return false }
        index = context.source.index(after: index)
        while index < context.source.endIndex && context.source[index].isNumber {
            index = context.source.index(after: index)
        }
        context.consuming = index
        let text = String(context.source[start..<index])
        context.tokens.append(FormulaToken.number(text, at: start..<index))
        return true
    }
}

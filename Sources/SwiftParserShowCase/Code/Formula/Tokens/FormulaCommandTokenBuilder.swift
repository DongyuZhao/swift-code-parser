import Foundation
import SwiftParser

public class FormulaCommandTokenBuilder: CodeTokenBuilder {
    public typealias Token = FormulaTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<FormulaTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        guard context.source[start] == "\\" else { return false }
        var index = context.source.index(after: start)
        while index < context.source.endIndex && context.source[index].isLetter {
            index = context.source.index(after: index)
        }
        context.consuming = index
        let name = String(context.source[start..<index])
        context.tokens.append(FormulaToken.command(name, at: start..<index))
        return true
    }
}

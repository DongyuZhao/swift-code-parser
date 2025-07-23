import Foundation
import SwiftParser

public class FormulaWhitespaceTokenBuilder: CodeTokenBuilder {
    public typealias Token = FormulaTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<FormulaTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        if context.source[context.consuming].isWhitespace {
            context.consuming = context.source.index(after: context.consuming)
            return true
        }
        return false
    }
}

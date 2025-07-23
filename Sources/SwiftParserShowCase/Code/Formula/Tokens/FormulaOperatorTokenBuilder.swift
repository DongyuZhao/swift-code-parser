import Foundation
import SwiftParser

@preconcurrency
public class FormulaOperatorTokenBuilder: CodeTokenBuilder {
    public typealias Token = FormulaTokenElement

    @preconcurrency nonisolated(unsafe) static let mapping: [Character: FormulaTokenElement] = [
        "+": .plus,
        "-": .minus,
        "*": .star,
        "/": .slash,
        "^": .caret,
        "_": .underscore,
        "=": .equals,
        "<": .less,
        ">": .greater,
        "|": .pipe
    ]

    public init() {}

    public func build(from context: inout CodeTokenContext<FormulaTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let char = context.source[context.consuming]
        guard let element = Self.mapping[char] else { return false }
        let start = context.consuming
        context.consuming = context.source.index(after: start)
        context.tokens.append(FormulaToken.symbol(element, at: start..<context.consuming))
        return true
    }
}

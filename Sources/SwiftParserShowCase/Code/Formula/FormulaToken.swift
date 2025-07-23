import Foundation
import SwiftParser

public class FormulaToken: CodeToken {
    public typealias Element = FormulaTokenElement

    public let element: FormulaTokenElement
    public let text: String
    public let range: Range<String.Index>

    public init(element: FormulaTokenElement, text: String, range: Range<String.Index>) {
        self.element = element
        self.text = text
        self.range = range
    }

    public static func number(_ text: String, at range: Range<String.Index>) -> FormulaToken {
        FormulaToken(element: .number, text: text, range: range)
    }

    public static func identifier(_ text: String, at range: Range<String.Index>) -> FormulaToken {
        FormulaToken(element: .identifier, text: text, range: range)
    }

    public static func command(_ name: String, at range: Range<String.Index>) -> FormulaToken {
        FormulaToken(element: .command, text: name, range: range)
    }

    public static func symbol(_ element: FormulaTokenElement, at range: Range<String.Index>) -> FormulaToken {
        FormulaToken(element: element, text: element.rawValue, range: range)
    }

    public static func eof(at range: Range<String.Index>) -> FormulaToken {
        FormulaToken(element: .eof, text: "", range: range)
    }
}

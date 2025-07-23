import Foundation
import SwiftParser

public enum FormulaTokenElement: String, CaseIterable, CodeTokenElement {
    case number
    case identifier
    case command
    case plus
    case minus
    case star
    case slash
    case caret
    case underscore
    case equals
    case lparen
    case rparen
    case lbrace
    case rbrace
    case eof
}

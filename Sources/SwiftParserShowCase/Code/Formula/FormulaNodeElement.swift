import Foundation
import SwiftParser

public enum FormulaNodeElement: String, CaseIterable, CodeNodeElement {
    case document
    case number
    case identifier
    case command
    case binaryOperation
    case group
}

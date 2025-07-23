import Foundation
import SwiftParser

public class FormulaLanguage: CodeLanguage {
    public typealias Node = FormulaNodeElement
    public typealias Token = FormulaTokenElement

    public var tokens: [any CodeTokenBuilder<FormulaTokenElement>]
    public let nodes: [any CodeNodeBuilder<FormulaNodeElement, FormulaTokenElement>]

    public init() {
        self.tokens = [
            FormulaWhitespaceTokenBuilder(),
            FormulaCommandTokenBuilder(),
            FormulaNumberTokenBuilder(),
            FormulaOperatorTokenBuilder(),
            FormulaDelimiterTokenBuilder(),
            FormulaIdentifierTokenBuilder()
        ]
        self.nodes = [
            FormulaExpressionBuilder(),
            FormulaEOFBuilder()
        ]
    }

    public func root() -> CodeNode<FormulaNodeElement> {
        FormulaDocumentNode()
    }

    public func state() -> (any CodeConstructState<Node, Token>)? { nil }
    public func state() -> (any CodeTokenState<Token>)? { nil }

    public func eofToken(at range: Range<String.Index>) -> (any CodeToken<FormulaTokenElement>)? {
        FormulaToken.eof(at: range)
    }
}

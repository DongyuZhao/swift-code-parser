import Foundation

/// Consumes a token and optionally updates the AST if it is recognized.
public protocol CodeTokenConsumer<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    func consume(token: any CodeToken<Token>, context: inout CodeContext<Node, Token>) -> Bool
}

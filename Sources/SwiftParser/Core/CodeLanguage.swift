import Foundation

public protocol CodeLanguage<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    var outdatedTokenizer: (any CodeOutdatedTokenizer<Token>)? { get }
    var tokens: [any CodeTokenBuilder<Token>] { get }
    var nodes: [any CodeNodeBuilder<Node, Token>] { get }

    func root(of content: String) -> CodeNode<Node>
    func state(of content: String) -> (any CodeParseState<Node, Token>)?
    func state(of content: String) -> (any CodeTokenState<Token>)?
}

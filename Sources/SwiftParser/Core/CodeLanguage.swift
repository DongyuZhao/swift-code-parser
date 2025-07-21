import Foundation

public protocol CodeLanguage<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    var tokenizer: any CodeOutdatedTokenizer<Token> { get }
    var tokens: [any CodeTokenBuilder<Token>] { get }
    var nodes: [any CodeNodeBuilder<Node, Token>] { get }

    func root() -> CodeNode<Node>
    func state() -> (any CodeConstructState<Node, Token>)?
    func state() -> (any CodeTokenState<Token>)?
}

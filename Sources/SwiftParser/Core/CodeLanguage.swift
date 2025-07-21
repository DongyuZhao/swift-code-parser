import Foundation

public protocol CodeLanguage<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    var tokenizer: any CodeTokenizer<Token> { get }
    var builders: [any CodeNodeBuilder<Node, Token>] { get }

    func root(of content: String) -> CodeNode<Node>
    func state(of content: String) -> (any CodeContextState<Node, Token>)?
}

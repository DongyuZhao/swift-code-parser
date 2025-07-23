import Foundation

public protocol CodeLanguage<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    /// The token builders used to tokenize the input.
    var tokens: [any CodeTokenBuilder<Token>] { get }

    /// The node builders used to construct the AST.
    var nodes: [any CodeNodeBuilder<Node, Token>] { get }

    /// The funtion that create the root node of the AST.
    func root() -> CodeNode<Node>

    /// The function that creates the initial context for AST construction.
    func state() -> (any CodeConstructState<Node, Token>)?

    /// The function that creates the initial context for tokenization.
    func state() -> (any CodeTokenState<Token>)?

    /// Provide an EOF token if the language requires one.
    /// - Parameter range: The range where the EOF token should be inserted.
    func eofToken(at range: Range<String.Index>) -> (any CodeToken<Token>)?
}

extension CodeLanguage {
    public func eofToken(at range: Range<String.Index>) -> (any CodeToken<Token>)? { nil }
}

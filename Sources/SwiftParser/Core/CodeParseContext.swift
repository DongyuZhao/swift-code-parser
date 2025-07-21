import Foundation

public protocol CodeParseState<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement
}

public class CodeParseContext<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    /// The current node being processed in the context
    public var current: CodeNode<Node>

    /// The tokens that need to be processed in this context
    public var tokens: [any CodeToken<Token>]

    /// The index of the next token to consume
    public var consuming: Int

    /// Any errors encountered during processing
    public var errors: [CodeError]

    /// The state of the processing, which can hold additional information
    public var state:  (any CodeParseState<Node, Token>)?

    public init(current: CodeNode<Node>, tokens: [any CodeToken<Token>], consuming: Int = 0, state: (any CodeParseState<Node, Token>)? = nil, errors: [CodeError] = []) {
        self.current = current
        self.tokens = tokens
        self.consuming = consuming
        self.state = state
        self.errors = errors
    }
}

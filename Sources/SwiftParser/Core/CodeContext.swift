import Foundation

public protocol CodeContextState<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement
}

public class CodeContext<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    public var current: CodeNode<Node>
    public var errors: [CodeError] = []
    public var state:  (any CodeContextState<Node, Token>)?

    public init(current: CodeNode<Node>, state: (any CodeContextState<Node, Token>)? = nil) {
        self.current = current
        self.state = state
    }
}

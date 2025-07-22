import Foundation

extension CodeLanguage {
    @available(*, deprecated, renamed: "root")
    public func root(of source: String) -> CodeNode<Node> {
        return root()
    }

    @available(*, deprecated, renamed: "state")
    public func state(of source: String) -> (any CodeConstructState<Node, Token>)? {
        return state()
    }
}

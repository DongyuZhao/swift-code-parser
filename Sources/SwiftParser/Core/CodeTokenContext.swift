public protocol CodeTokenState<Token> where Token: CodeTokenElement {
    associatedtype Token: CodeTokenElement
}

public class CodeTokenContext<Element> where Element: CodeTokenElement {
    public let source: String
    public var consuming: String.Index
    public let state: (any CodeTokenState<Element>)?
    public var tokens: [any CodeToken<Element>] = []
    public var errors: [CodeError] = []

    public init(source: String, consuming: String.Index, state: (any CodeTokenState<Element>)? = nil) {
        self.source = source
        self.consuming = consuming
        self.state = state
    }
}
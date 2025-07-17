import Foundation

public struct CodeContext {
    public var tokens: [any CodeToken]
    public var currentNode: CodeNode
    public var errors: [CodeError]

    public init(tokens: [any CodeToken], currentNode: CodeNode, errors: [CodeError]) {
        self.tokens = tokens
        self.currentNode = currentNode
        self.errors = errors
    }
}

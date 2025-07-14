import Foundation

public protocol CodeElement {}

public protocol CodeToken {
    var kindDescription: String { get }
    var text: String { get }
    var range: Range<String.Index> { get }
}

public protocol CodeTokenizer {
    func tokenize(_ input: String) -> [any CodeToken]
}

public protocol CodeElementBuilder {
    func accept(context: CodeContext, token: any CodeToken) -> Bool
    func build(context: inout CodeContext)
}

public final class CodeNode {
    public let type: any CodeElement
    public var value: String
    public weak var parent: CodeNode?
    public var children: [CodeNode] = []
    public var range: Range<String.Index>?

    public var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(value)
        for child in children {
            hasher.combine(child.id)
        }
        return hasher.finalize()
    }

    public init(type: any CodeElement, value: String, range: Range<String.Index>? = nil) {
        self.type = type
        self.value = value
        self.range = range
    }

    public func addChild(_ node: CodeNode) {
        node.parent = self
        children.append(node)
    }
}

public struct CodeError: Error {
    public let message: String
    public let range: Range<String.Index>?
    public init(_ message: String, range: Range<String.Index>? = nil) {
        self.message = message
        self.range = range
    }
}

public struct CodeContext {
    public var tokens: [any CodeToken]
    public var index: Int
    public var currentNode: CodeNode
    public var errors: [CodeError]
    public let input: String

    public init(tokens: [any CodeToken], index: Int, currentNode: CodeNode, errors: [CodeError], input: String) {
        self.tokens = tokens
        self.index = index
        self.currentNode = currentNode
        self.errors = errors
        self.input = input
    }
}

public protocol CodeLanguage {
    var tokenizer: CodeTokenizer { get }
    var builders: [CodeElementBuilder] { get }
    var rootElement: any CodeElement { get }
    var expressionBuilder: CodeExpressionBuilder? { get }
}

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

public class CodeNode {
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
    public var linkReferences: [String: String]

    public init(tokens: [any CodeToken], index: Int, currentNode: CodeNode, errors: [CodeError], input: String, linkReferences: [String: String] = [:]) {
        self.tokens = tokens
        self.index = index
        self.currentNode = currentNode
        self.errors = errors
        self.input = input
        self.linkReferences = linkReferences
    }

    /// Snapshot represents a parser state that can be restored later.
    public struct Snapshot {
        fileprivate let index: Int
        fileprivate let node: CodeNode
        fileprivate let childCount: Int
        fileprivate let errorCount: Int
        fileprivate let linkReferences: [String: String]
    }

    /// Capture the current parser state so it can be restored on demand.
    public func snapshot() -> Snapshot {
        Snapshot(index: index, node: currentNode, childCount: currentNode.children.count, errorCount: errors.count, linkReferences: linkReferences)
    }

    /// Restore the parser to a previously captured state, discarding any new nodes or errors.
    public mutating func restore(_ snapshot: Snapshot) {
        index = snapshot.index
        currentNode = snapshot.node
        if currentNode.children.count > snapshot.childCount {
            currentNode.children.removeLast(currentNode.children.count - snapshot.childCount)
        }
        if errors.count > snapshot.errorCount {
            errors.removeLast(errors.count - snapshot.errorCount)
        }
        linkReferences = snapshot.linkReferences
    }
}

public protocol CodeLanguage {
    var tokenizer: CodeTokenizer { get }
    var builders: [CodeElementBuilder] { get }
    var rootElement: any CodeElement { get }
    var expressionBuilders: [CodeExpressionBuilder] { get }
}

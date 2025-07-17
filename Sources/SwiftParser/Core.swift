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

/// Consumes a token and optionally updates the AST if it is recognized.
/// - Returns: `true` if the token was handled and the context advanced.
public protocol CodeTokenConsumer {
    func consume(context: inout CodeContext, token: any CodeToken) -> Bool
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

    /// Insert a child node at the specified index
    public func insertChild(_ node: CodeNode, at index: Int) {
        node.parent = self
        children.insert(node, at: index)
    }

    /// Remove and return the child node at the given index
    @discardableResult
    public func removeChild(at index: Int) -> CodeNode {
        let removed = children.remove(at: index)
        removed.parent = nil
        return removed
    }

    /// Replace the child node at the given index with another node
    public func replaceChild(at index: Int, with node: CodeNode) {
        children[index].parent = nil
        node.parent = self
        children[index] = node
    }

    /// Detach this node from its parent
    public func removeFromParent() {
        parent?.children.removeAll { $0 === self }
        parent = nil
    }

    /// Depth-first traversal of this node and all descendants
    public func traverseDepthFirst(_ visit: (CodeNode) -> Void) {
        visit(self)
        for child in children {
            child.traverseDepthFirst(visit)
        }
    }

    /// Breadth-first traversal of this node and all descendants
    public func traverseBreadthFirst(_ visit: (CodeNode) -> Void) {
        var queue: [CodeNode] = [self]
        while !queue.isEmpty {
            let node = queue.removeFirst()
            visit(node)
            queue.append(contentsOf: node.children)
        }
    }

    /// Return the first node in the subtree satisfying the predicate
    public func first(where predicate: (CodeNode) -> Bool) -> CodeNode? {
        if predicate(self) { return self }
        for child in children {
            if let result = child.first(where: predicate) {
                return result
            }
        }
        return nil
    }

    /// Return all nodes in the subtree satisfying the predicate
    public func findAll(where predicate: (CodeNode) -> Bool) -> [CodeNode] {
        var results: [CodeNode] = []
        traverseDepthFirst { node in
            if predicate(node) { results.append(node) }
        }
        return results
    }

    /// Number of nodes in this subtree including this node
    public var subtreeCount: Int {
        1 + children.reduce(0) { $0 + $1.subtreeCount }
    }

    /// Depth of this node from the root node
    public var depth: Int {
        var d = 0
        var current = parent
        while let p = current {
            d += 1
            current = p.parent
        }
        return d
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
    public var currentNode: CodeNode
    public var errors: [CodeError]

    public init(tokens: [any CodeToken], currentNode: CodeNode, errors: [CodeError]) {
        self.tokens = tokens
        self.currentNode = currentNode
        self.errors = errors
    }
}

public protocol CodeLanguage {
    var tokenizer: CodeTokenizer { get }
    var consumers: [CodeTokenConsumer] { get }
    var rootElement: any CodeElement { get }
}

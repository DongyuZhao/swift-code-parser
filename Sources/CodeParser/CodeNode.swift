import Foundation

public protocol CodeNodeElement: CaseIterable, RawRepresentable where RawValue == String {}

open class CodeNode<Node> where Node: CodeNodeElement {
    public let element: Node
    public weak var parent: CodeNode<Node>?
    public var children: [CodeNode<Node>] = []

    /// The node's id relies on its element and children
    public var id: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        for child in children {
            hasher.combine(child.id)
        }
        return hasher.finalize()
    }

    public init(element: Node) {
        self.element = element
    }

    /// The function to compute the hash value of this node.
    /// Since some structure node do not have hashable content, we leave this function open.
    /// Each subclass can override this method to provide its own hash logic.
    open func hash(into hasher: inout Hasher) {
        hasher.combine(element.rawValue)
    }

    // MARK: - Child management

    /// Add a child node to this node
    public func append(_ node: CodeNode<Node>) {
        node.parent = self
        children.append(node)
    }

    /// Insert a child node at the specified index
    public func insert(_ node: CodeNode<Node>, at index: Int) {
        node.parent = self
        children.insert(node, at: index)
    }

    /// Remove and return the child node at the given index
    @discardableResult
    public func remove(at index: Int) -> CodeNode<Node> {
        let removed = children.remove(at: index)
        removed.parent = nil
        return removed
    }

    /// Detach this node from its parent
    public func remove() {
        parent?.children.removeAll { $0 === self }
        parent = nil
    }

    /// Replace the child node at the given index with another node
    public func replace(at index: Int, with node: CodeNode<Node>) {
        children[index].parent = nil
        node.parent = self
        children[index] = node
    }

    // MARK: - Traversal and Searching

    /// Depth-first traversal of this node and all descendants
    public func dfs(_ visit: (CodeNode<Node>) -> Void) {
        visit(self)
        for child in children {
            child.dfs(visit)
        }
    }

    /// Breadth-first traversal of this node and all descendants
    public func bfs(_ visit: (CodeNode<Node>) -> Void) {
        var queue: [CodeNode<Node>] = [self]
        while !queue.isEmpty {
            let node = queue.removeFirst()
            visit(node)
            queue.append(contentsOf: node.children)
        }
    }

    /// Return the first node in the subtree satisfying the predicate
    public func first(where predicate: (CodeNode<Node>) -> Bool) -> CodeNode<Node>? {
        if predicate(self) { return self }
        for child in children {
            if let result = child.first(where: predicate) {
                return result
            }
        }
        return nil
    }

    /// Return all nodes in the subtree satisfying the predicate
    public func nodes(where predicate: (CodeNode<Node>) -> Bool) -> [CodeNode<Node>] {
        var results: [CodeNode<Node>] = []
        dfs { node in
            if predicate(node) { results.append(node) }
        }
        return results
    }

    /// Number of nodes in this subtree including this node
    public var count: Int {
        1 + children.reduce(0) { $0 + $1.count }
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

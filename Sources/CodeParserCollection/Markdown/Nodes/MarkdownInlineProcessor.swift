import CodeParserCore
import Foundation

// MARK: - Inline Processing Protocols

/// Protocol for inline syntax processors that handle specific markdown constructs
public protocol MarkdownContentProcessor {
  /// The delimiter characters this processor handles (e.g., "*", "_", "[", "`")
  var delimiters: Set<Character> { get }

  /// Process a token and optionally create inline nodes or delimiter runs
  /// Returns true if the token was handled, false otherwise
  ///
  /// Notes:
  /// - Tokens with element `.punctuation` are guaranteed to carry exactly ONE character.
  ///   For delimiter runs like `***` or `___`, processors should aggregate consecutive
  ///   single-character punctuation tokens into a run, compute canOpen/canClose, and then
  ///   push a `DelimiterRun` with the combined length.
  /// - When a processor consumes multiple consecutive tokens as one run, it SHOULD advance
  ///   `context.currentTokenIndex` accordingly (e.g., by `runLength - 1`). The outer loop
  ///   will still increment by 1 after `process` returns, resulting in a total advance of
  ///   `runLength` and preventing double-processing.
  func process(
    _ token: any CodeToken<MarkdownTokenElement>,
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> Bool

  /// Process delimiter runs when finalizing (called at end of processing)
  /// This is where emphasis/strong processing would happen
  func finalize(context: inout MarkdownContentContext)
}

/// Context passed to inline processors containing shared state
public struct MarkdownContentContext {
  /// The delimiter stack for managing nested constructs
  public var delimiters: MarkdownDelimiterStack

  /// Current inline nodes being built
  public var inlined: [MarkdownNodeBase]

  /// Current token index being processed
  public var current: Int

  /// All tokens in the content
  public let tokens: [any CodeToken<MarkdownTokenElement>]

  public init(tokens: [any CodeToken<MarkdownTokenElement>]) {
    self.delimiters = MarkdownDelimiterStack()
    self.inlined = []
    self.current = 0
    self.tokens = tokens
  }

  /// Helper to add text node or merge with previous text node
  /// Only merges if the last node is not a delimiter in the delimiter stack
  public mutating func add(_ text: String) {
    if let last = inlined.last as? TextNode,
       !isDelimiterTextNode(last) {
      last.content += text
    } else {
      inlined.append(TextNode(content: text))
    }
  }

  /// Check if a text node is associated with a delimiter in the stack
  private func isDelimiterTextNode(_ textNode: TextNode) -> Bool {
    return delimiters.contains(textNode)
  }

  /// Helper to add any inline node
  public mutating func add(_ node: MarkdownNodeBase) {
    inlined.append(node)
  }

  /// Advance the current token index by a delta (can be negative if needed, but use with care).
  /// Typical usage: when a processor aggregates a delimiter run spanning N tokens, it may call
  /// `advanceCurrentTokenIndex(by: N - 1)` so that the outer loop's `+1` results in skipping N.
  public mutating func advance(by delta: Int) {
    current += delta
  }
}

// MARK: - Delimiter Stack (Extracted from ContentBuilder)

public enum MarkdownDelimiter: Hashable {
  case asterisk
  case underscore
  case openBracket
  case openImageBracket
  case backtick(count: Int)
  case custom(String)
}

public struct MarkdownDelimiterRun {
  public let delimiter: MarkdownDelimiter
  public let length: Int
  public let openable: Bool
  public let closable: Bool
  public let index: Int
  public var isActive: Bool = true

  public init(type: MarkdownDelimiter, length: Int, openable: Bool, closable: Bool, index: Int) {
    self.delimiter = type
    self.length = length
    self.openable = openable
    self.closable = closable
    self.index = index // token index
  }
}

public class MarkdownDelimiterStackNode {
  public var run: MarkdownDelimiterRun
  public var text: TextNode?
  public weak var previous: MarkdownDelimiterStackNode?
  public var next: MarkdownDelimiterStackNode?

  public init(delimiterRun: MarkdownDelimiterRun, textNode: TextNode? = nil) {
    self.run = delimiterRun
    self.text = textNode
  }
}

public class MarkdownDelimiterStack {
  private var head: MarkdownDelimiterStackNode?
  private var tail: MarkdownDelimiterStackNode?

  public init() {}

  public func push(_ delimiterRun: MarkdownDelimiterRun, textNode: TextNode? = nil) {
    let node = MarkdownDelimiterStackNode(delimiterRun: delimiterRun, textNode: textNode)

    if let currentTail = tail {
      currentTail.next = node
      node.previous = currentTail
      tail = node
    } else {
      head = node
      tail = node
    }
  }

  public func remove(_ node: MarkdownDelimiterStackNode) {
    if node.previous != nil {
      node.previous?.next = node.next
    } else {
      head = node.next
    }

    if node.next != nil {
      node.next?.previous = node.previous
    } else {
      tail = node.previous
    }
  }

  public func opener(for type: MarkdownDelimiter, before node: MarkdownDelimiterStackNode?) -> MarkdownDelimiterStackNode? {
    var current = node?.previous ?? tail
    while let currentNode = current {
      if currentNode.run.delimiter == type &&
         currentNode.run.openable &&
         currentNode.run.isActive {
        return currentNode
      }
      current = currentNode.previous
    }
    return nil
  }

  public func clear(after stackBottom: MarkdownDelimiterStackNode?) {
    var current = stackBottom?.next ?? head
    while let node = current {
      let next = node.next
      remove(node)
      current = next
    }
  }

  public var isEmpty: Bool {
    return head == nil
  }

  public func forward(from start: MarkdownDelimiterStackNode?) -> MarkdownDelimiterStackIterator {
    return MarkdownDelimiterStackIterator(current: start ?? head)
  }

  public func contains(_ textNode: TextNode) -> Bool {
    var current = head
    while let node = current {
      if node.text === textNode {
        return true
      }
      current = node.next
    }
    return false
  }
}

public struct MarkdownDelimiterStackIterator: IteratorProtocol {
  private var current: MarkdownDelimiterStackNode?

  public init(current: MarkdownDelimiterStackNode?) {
    self.current = current
  }

  public mutating func next() -> MarkdownDelimiterStackNode? {
    let result = current
    current = current?.next
    return result
  }
}

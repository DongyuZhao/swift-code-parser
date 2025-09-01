import CodeParserCore
import Foundation

/// Protocol for Markdown inline builders following CommonMark delimiter stack rules
/// Each builder handles specific inline elements like emphasis, links, code spans, etc.
public protocol MarkdownInlineBuilderProtocol {
  
  /// Check if this builder can handle the current position in the token stream
  /// - Parameters:
  ///   - tokens: The token stream
  ///   - position: Current position in the stream
  ///   - state: The current parsing state
  /// - Returns: true if this builder can handle the current position
  func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool
  
  /// Process inline element at the current position
  /// - Parameters:
  ///   - tokens: The token stream
  ///   - position: Current position in the stream (will be modified)
  ///   - delimiterStack: The delimiter stack for emphasis processing
  ///   - state: The current parsing state
  ///   - context: The construct context for node operations
  /// - Returns: The created inline node, or nil if processing failed
  func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase?
  
  /// The priority of this builder (lower numbers have higher priority)
  var priority: Int { get }
  
  /// The type of inline element this builder handles
  var inlineType: MarkdownNodeElement { get }
}

/// Represents a delimiter on the delimiter stack for emphasis processing
public struct DelimiterEntry {
  /// The delimiter character (* or _)
  let character: String
  /// The number of delimiter characters
  let count: Int
  /// Position in the token stream where this delimiter starts
  let position: Int
  /// Whether this delimiter can open emphasis
  let canOpen: Bool
  /// Whether this delimiter can close emphasis
  let canClose: Bool
  /// The node that will contain the emphasized text (if this becomes an opener)
  var node: MarkdownNodeBase?
  
  public init(character: String, count: Int, position: Int, canOpen: Bool, canClose: Bool) {
    self.character = character
    self.count = count
    self.position = position
    self.canOpen = canOpen
    self.canClose = canClose
    self.node = nil
  }
}

/// Default implementations for optional behavior
public extension MarkdownInlineBuilderProtocol {
  var priority: Int { 
    return 100 // Default priority
  }
}
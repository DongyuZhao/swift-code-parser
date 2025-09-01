import CodeParserCore
import Foundation

/// Protocol for CommonMark block builders following the CommonMark parsing strategy
/// Each builder focuses only on its specific block type without grammar specification
public protocol CommonMarkBlockBuilder {
  
  /// Check if this builder can continue processing an existing open block with the current line
  /// - Parameters:
  ///   - block: The currently open block to check for continuation
  ///   - line: The current line tokens to process
  ///   - state: The current parsing state
  /// - Returns: true if this builder can continue the block, false otherwise
  func canContinue(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool
  
  /// Check if this builder can start a new block with the current line
  /// - Parameters:
  ///   - line: The current line tokens to process
  ///   - state: The current parsing state
  /// - Returns: true if this builder can start a new block, false otherwise
  func canStart(
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool
  
  /// Create a new block from the current line
  /// - Parameters:
  ///   - line: The current line tokens to process
  ///   - state: The current parsing state
  ///   - context: The construct context for creating nodes
  /// - Returns: The newly created block node, or nil if creation failed
  func createBlock(
    from line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase?
  
  /// Process the current line for an existing block (continuation)
  /// - Parameters:
  ///   - block: The block to process the line for
  ///   - line: The current line tokens to process
  ///   - state: The current parsing state
  ///   - context: The construct context for node operations
  /// - Returns: true if the line was successfully processed, false otherwise
  func processLine(
    for block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool
  
  /// Check if the block should be closed based on the current line
  /// - Parameters:
  ///   - block: The block to check for closing
  ///   - line: The current line tokens to process
  ///   - state: The current parsing state
  /// - Returns: true if the block should be closed, false otherwise
  func shouldClose(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool
  
  /// The priority of this builder (lower numbers have higher priority)
  var priority: Int { get }
  
  /// The type of block this builder handles
  var blockType: MarkdownNodeElement { get }
}

/// Default implementations for optional behavior
public extension CommonMarkBlockBuilder {
  func shouldClose(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // By default, blocks don't auto-close unless explicitly overridden
    return false
  }
  
  var priority: Int { 
    return 100 // Default priority
  }
}
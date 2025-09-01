import CodeParserCore
import Foundation

/// Protocol for pluggable Markdown block builders that work within the CommonMark parsing algorithm
/// These builders are NOT CodeNodeBuilders - they work with line-based processing within MarkdownBlockBuilder
public protocol MarkdownBlockBuilderProtocol {
  
  /// Check if this builder can start a new block with the given line
  /// - Parameter line: The line tokens to examine
  /// - Returns: True if this builder can handle this line as a new block start
  func canStart(line: MarkdownLine) -> Bool
  
  /// Check if this builder can continue an existing block with the given line
  /// - Parameters:
  ///   - block: The existing block being processed
  ///   - line: The line tokens to examine
  /// - Returns: True if this builder can continue the block with this line
  func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool
  
  /// Create a new block from the given line
  /// - Parameter line: The line tokens to process
  /// - Returns: The created block node, or nil if creation failed
  func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)?
  
  /// Process a line for an existing block
  /// - Parameters:
  ///   - block: The existing block to add content to
  ///   - line: The line tokens to process
  /// - Returns: True if the line was successfully processed
  func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool
  
  /// Close and finalize a block (post-processing)
  /// - Parameter block: The block to finalize
  func closeBlock(block: any MarkdownBlockNode)
}

/// Represents a line of tokens for block processing
public struct MarkdownLine {
  public let tokens: [any CodeToken<MarkdownTokenElement>]
  public let lineNumber: Int
  
  public init(tokens: [any CodeToken<MarkdownTokenElement>], lineNumber: Int) {
    self.tokens = tokens
    self.lineNumber = lineNumber
  }
  
  /// Get the content of this line as a string
  public var content: String {
    return tokens.map { $0.text }.joined()
  }
  
  /// Check if this line is blank (only whitespace/newline)
  public var isBlank: Bool {
    return tokens.allSatisfy { token in
      token.element == .whitespaces || token.element == .newline || token.element == .eof
    }
  }
  
  /// Get leading whitespace count
  public var leadingWhitespace: Int {
    guard let firstToken = tokens.first,
          firstToken.element == .whitespaces else {
      return 0
    }
    return firstToken.text.count
  }
}

/// Base protocol for Markdown block nodes
public protocol MarkdownBlockNode: AnyObject {
  var blockType: String { get }
}

/// Extension to add default implementations
extension MarkdownBlockBuilderProtocol {
  /// Default implementation that returns false - override if the builder needs closing logic
  public func closeBlock(block: any MarkdownBlockNode) {
    // Default: no special closing logic needed
  }
}
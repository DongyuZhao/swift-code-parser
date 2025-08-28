import CodeParserCore
import Foundation

/// Main construction state for Markdown language with line-based processing
public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // Current token index in the line
  public var position: Int = 0
  // Flag indicates if the block builders should run another round on the same line.
  public var refreshed: Bool = false
  // Flag indicates if the current line is being reprocessed after partial consumption
  public var isPartialLine: Bool = false
  
  // Fenced code block state
  public var openFence: OpenFenceInfo?
  
  /// Stack for nested list processing
  public var listStack: [ListNode] = []
  public var currentDefinitionList: DefinitionListNode?

  /// Indicates the last consumed line break formed a blank line (two or more consecutive newlines)
  public var lastWasBlankLine: Bool = false

  /// When a quoted blank line (`>\\n`) is seen inside a blockquote, the next quoted
  /// content should start a new paragraph inside the same blockquote instead of
  /// merging into the previous one.
  public var pendingBlockquoteParagraphSplit: Bool = false

  /// True when the previous quoted line (inside a blockquote) began with a token
  /// that could start a block (e.g., `#`, `-`, `*`, `+`, number.). We use this to
  /// prevent merging the next quoted line into the same paragraph, matching CommonMark
  /// semantics where block-starting constructs introduce a new block.
  public var prevBlockquoteLineWasBlockStart: Bool = false

  public init() {}
}

/// Information about an open fenced code block
public struct OpenFenceInfo {
  public let character: String
  public let length: Int
  public let indentation: Int
  public let codeBlock: CodeBlockNode
  
  public init(character: String, length: Int, indentation: Int, codeBlock: CodeBlockNode) {
    self.character = character
    self.length = length
    self.indentation = indentation
    self.codeBlock = codeBlock
  }
}

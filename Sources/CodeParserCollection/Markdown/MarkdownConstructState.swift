import CodeParserCore
import Foundation

public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  /// Stack for nested list processing
  public var listStack: [ListNode] = []
  public var currentDefinitionList: DefinitionListNode?

  /// Indicates the last consumed line break formed a blank line (two or more consecutive newlines)
  public var lastWasBlankLine: Bool = false

  /// When a quoted blank line (`>\n`) is seen inside a blockquote, the next quoted
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

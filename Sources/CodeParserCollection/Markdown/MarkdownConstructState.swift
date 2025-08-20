import CodeParserCore
import Foundation

/// Main construction state for Markdown language with line-based processing
public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // Line-based processing state
  public var lines: [MarkdownLine] = []
  public var currentLineIndex: Int = 0

  public init() {}
}

/// Represents a logical line of tokens
public struct MarkdownLine {
  public let tokens: [any CodeToken<MarkdownTokenElement>]
}

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
  
  // Fenced code block state
  public var openFence: OpenFenceInfo?

  public init() {}
}

/// Information about an open fenced code block
public struct OpenFenceInfo {
  public let character: String
  public let length: Int
  public let codeBlock: CodeBlockNode
  
  public init(character: String, length: Int, codeBlock: CodeBlockNode) {
    self.character = character
    self.length = length
    self.codeBlock = codeBlock
  }
}

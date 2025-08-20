import CodeParserCore
import Foundation

/// Placeholder builder for admonition blocks (e.g., `!!! note`).
/// Parsing for admonitions is not implemented in this phase.
public struct MarkdownAdmonitionNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    return false
  }
}


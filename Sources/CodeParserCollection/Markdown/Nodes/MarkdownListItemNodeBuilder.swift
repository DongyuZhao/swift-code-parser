import CodeParserCore
import Foundation

/// Placeholder builder for standalone list items. In the current phase the
/// list builders create list items directly, so this builder simply returns
/// `false`. It exists to satisfy the requirement that each block element has a
/// corresponding builder.
public struct MarkdownListItemNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    return false
  }
}


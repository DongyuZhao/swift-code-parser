import CodeParserCore
import Foundation

/// Placeholder builder for definition lists. Definition list support is not
/// yet implemented, so this builder currently returns `false` and performs
/// no parsing.
public struct MarkdownDefinitionNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    return false
  }
}


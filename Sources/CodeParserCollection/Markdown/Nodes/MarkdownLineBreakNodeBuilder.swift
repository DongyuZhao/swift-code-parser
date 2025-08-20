import CodeParserCore
import Foundation

/// Builder for Markdown soft and hard line breaks.
public struct MarkdownLineBreakNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count,
          let token = context.tokens[context.consuming] as? MarkdownToken else { return false }
    switch token.element {
    case .newline:
      let node = LineBreakNode(variant: .soft)
      context.current.append(node)
      context.consuming += 1
      return true
    case .hardbreak:
      let node = LineBreakNode(variant: .hard)
      context.current.append(node)
      context.consuming += 1
      return true
    default:
      return false
    }
  }
}

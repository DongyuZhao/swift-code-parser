import CodeParserCore
import Foundation

/// Consumes the EOF token to avoid parse errors at the end of input.
public class MarkdownEOFBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    if context.consuming < context.tokens.count,
       context.tokens[context.consuming].element == .eof {
      context.consuming += 1
      MarkdownReferenceResolver.resolve(in: context.current)
      removeDefinitions(from: context.current)
      if let state = context.state as? MarkdownConstructState {
        state.previousLineBlank = true
      }
      return true
    }
    return false
  }

  private func removeDefinitions(from node: CodeNode<MarkdownNodeElement>) {
    node.children.removeAll { child in
      if let ref = child as? ReferenceNode, !ref.url.isEmpty { return true }
      return false
    }
    for child in node.children {
      removeDefinitions(from: child)
    }
  }
}

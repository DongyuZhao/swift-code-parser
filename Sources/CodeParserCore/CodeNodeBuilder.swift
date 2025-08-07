import Foundation

/// Consume tokens to build a tree of nodes.
public protocol CodeNodeBuilder<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
  associatedtype Node: CodeNodeElement
  associatedtype Token: CodeTokenElement

  /// Attempt to build part of the AST from the context.
  /// Returns true if the builder successfully consumed tokens and updated the context.
  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool
}

//
//  CodeParser.swift
//  CodeParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

/// Consumes a list of tokens to build an AST using registered node builders.
public class CodeConstructor<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
  /// Ordered collection of node builders that attempt to consume tokens.
  private let builders: [any CodeNodeBuilder<Node, Token>]
  /// Factory that provides initial construction state for each parse run.
  private var state: () -> (any CodeConstructState<Node, Token>)?

  /// Create a new constructor
  /// - Parameters:
  ///   - builders: The node builders responsible for producing AST nodes.
  ///   - state: Factory returning the initial parsing state object.
  public init(
    builders: [any CodeNodeBuilder<Node, Token>],
    state: @escaping () -> (any CodeConstructState<Node, Token>)?
  ) {
    self.builders = builders
    self.state = state
  }

  /// Build an AST from a token stream
  /// - Parameters:
  ///   - tokens: Token list to consume.
  ///   - root: Root node that will receive parsed children.
  /// - Returns: The populated root node and any construction errors.
  public func parse(_ tokens: [any CodeToken<Token>], root: CodeNode<Node>) -> (
    CodeNode<Node>, [CodeError]
  ) {
    var context = CodeConstructContext(current: root, tokens: tokens, state: state())

    while context.consuming < context.tokens.count {

      var matched = false
      for node in builders {
        let before = context.consuming
        if node.build(from: &context) {
          matched = true
          // Safety guard: ensure progress to avoid infinite loops when a builder
          // returns true without consuming any tokens.
          if context.consuming == before {
            let token = context.tokens[context.consuming]
            let error = CodeError(
              "Builder made no progress on token: \(token.element)", range: token.range)
            context.errors.append(error)
            context.consuming += 1
          }
          break
        }
      }

      if !matched {
        // If no builder matched, record an error and skip the token
        let token = context.tokens[context.consuming]
        let error = CodeError("Unrecognized token: \(token.element)", range: token.range)
        context.errors.append(error)
        context.consuming += 1
      }
    }

    return (root, context.errors)
  }
}

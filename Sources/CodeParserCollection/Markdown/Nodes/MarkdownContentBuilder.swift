import CodeParserCore
import Foundation

/// Builder that parses inline Markdown content by delegating to a set of
/// specialized inline node builders.
///
/// This centralizes inline parsing so that block-level builders can simply
/// provide the tokens that make up their textual content and rely on this
/// builder for dispatch and state management.
public struct MarkdownContentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  /// Ordered list of inline builders to run when parsing content.
  private let builders: [any CodeNodeBuilder<Node, Token>]

  public init(
    builders: [any CodeNodeBuilder<Node, Token>] = [
      MarkdownHTMLNodeBuilder(),
      MarkdownStrikeNodeBuilder(),
      MarkdownStrongNodeBuilder(),
      MarkdownImageNodeBuilder(),
      MarkdownCodeNodeBuilder(),
      MarkdownLineBreakNodeBuilder(),
      MarkdownLinkNodeBuilder(),
      MarkdownEmphasisNodeBuilder(),
      MarkdownTextNodeBuilder(),
    ]
  ) {
    self.builders = builders
  }

  /// Parse all tokens in the provided context as inline content.
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let initial = context.consuming

    while context.consuming < context.tokens.count {
      var matched = false
      for builder in builders {
        let before = context.consuming
        if builder.build(from: &context) {
          matched = true
          // Ensure progress to avoid infinite loops where a builder succeeds
          // without consuming any tokens.
          if context.consuming == before {
            context.consuming += 1
          }
          break
        }
      }

      if !matched {
        let token = context.tokens[context.consuming]
        context.errors.append(
          CodeError("Unrecognized inline token: \(token.element)", range: token.range)
        )
        context.consuming += 1
      }
    }

    return context.consuming > initial
  }
}


import CodeParserCore
import Foundation

/// Handles block quotes starting with > characters
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#block-quotes
/// This is a container builder that uses position/refreshed mechanism for nested content
public class MarkdownBlockQuoteBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    var index = startIndex
    
    // Skip leading whitespace (up to 3 spaces allowed before >)
    var leadingSpaces = 0
    while index < context.tokens.count,
          let token = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      let spaceCount = token.text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Must have > character
    guard index < context.tokens.count,
          let token = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == ">" else {
      return false
    }
    
    index += 1 // consume the >
    
    // Optionally consume one space after >
    if index < context.tokens.count,
       let nextToken = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
       nextToken.element == .whitespaces,
       nextToken.text == " " {
      index += 1
    }
    
    // Create or reuse blockquote
    let blockquote: BlockquoteNode
    if let currentBlockquote = context.current as? BlockquoteNode {
      // We're already inside a blockquote, continue using it
      blockquote = currentBlockquote
    } else {
      // Check if the last child is a blockquote we can continue
      if let lastChild = context.current.children.last as? BlockquoteNode {
        blockquote = lastChild
      } else {
        // Create new blockquote
        blockquote = BlockquoteNode()
        context.current.append(blockquote)
      }
    }
    
    // Set current context to the blockquote for nested content
    context.current = blockquote
    
    // Update state to process remaining tokens as nested content
    state.position = index
    state.refreshed = true
    
    return true
  }
}
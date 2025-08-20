import CodeParserCore
import Foundation

/// Builder for Markdown text inline elements.
/// Collects contiguous character, whitespace, punctuation, or entity tokens
/// and emits a single TextNode.
public struct MarkdownTextNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count,
          let token = context.tokens[start] as? MarkdownToken else { return false }

    switch token.element {
    case .characters, .whitespaces, .punctuation, .charef:
      var current = start
      outer: while current < context.tokens.count {
        guard let tok = context.tokens[current] as? MarkdownToken else { break }
        switch tok.element {
        case .characters, .whitespaces, .punctuation, .charef:
          current += 1
        default:
          break outer
        }
      }
      let slice = context.tokens[start..<current]
      let content = tokensToString(slice)
      let node = TextNode(content: content)
      context.current.append(node)
      context.consuming = current
      return true
    default:
      return false
    }
  }
}

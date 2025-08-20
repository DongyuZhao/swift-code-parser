import CodeParserCore
import Foundation

/// Builder for HTML blocks starting with `<` and continuing until the end
/// of the line. This is a naive implementation that does not attempt to
/// match full HTML block rules from the specification.
public struct MarkdownHTMLBlockNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count else { return false }

    var current = start
    // Skip leading spaces
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .whitespaces {
      current += 1
    }

    guard current < context.tokens.count,
          let lt = context.tokens[current] as? MarkdownToken,
          lt.element == .punctuation, lt.text == "<" else { return false }
    current += 1

    // Capture tag name
    var name = ""
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .characters {
      name += tok.text
      current += 1
    }

    // Capture rest of line as content including tag name
    var content = "<" + name
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .newline || tok.element == .hardbreak || tok.element == .eof {
        break
      }
      content += tok.text
      current += 1
    }

    let node = HTMLBlockNode(name: name, content: content)
    context.current.append(node)
    context.consuming = current
    return true
  }
}


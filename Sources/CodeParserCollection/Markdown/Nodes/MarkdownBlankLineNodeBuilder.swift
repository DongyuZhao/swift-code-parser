import CodeParserCore
import Foundation

/// Builder recognizing blank lines consisting only of optional whitespace
/// followed by a newline. Blank lines are used to terminate paragraphs and
/// other block constructs.
public struct MarkdownBlankLineNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count else { return false }

    var current = start
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .whitespaces {
      current += 1
    }
    guard current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .newline || tok.element == .hardbreak || tok.element == .eof
    else { return false }
    current += 1

    context.current.append(CodeNode<Node>(element: .blankLine))
    context.consuming = current
    return true
  }
}


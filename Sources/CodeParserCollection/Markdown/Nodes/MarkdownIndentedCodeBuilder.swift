import CodeParserCore
import Foundation

public class MarkdownIndentedCodeBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .indentedCodeBlock,
      isStartOfLine(context)
    else { return false }

  context.consuming += 1
  let node = CodeBlockNode(source: stripIndent(token.text))
    // If we're currently positioned at a list container, a blank line has
    // already moved `current` up from the last list item. In this case the
    // indented code block should terminate the list and attach to its parent
    // (usually the document root).
    let target: CodeNode<MarkdownNodeElement>
    if context.current.element == .orderedList || context.current.element == .unorderedList {
      target = context.current.parent ?? context.current
    } else {
      target = context.current
    }
    target.append(node)
    context.current = target
    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
    return true
  }

  private func isStartOfLine(
    _ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    if context.consuming == 0 { return true }
    if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
      return prev.element == .newline
    }
    return false
  }

  private func stripIndent(_ raw: String) -> String {
    var result: [String] = []
    for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
      var toDrop = 4
  let out = String(line)
      var idx = out.startIndex
      while toDrop > 0 && idx < out.endIndex {
        let c = out[idx]
        if c == " " { toDrop -= 1; idx = out.index(after: idx) }
        else if c == "\t" { toDrop = 0; idx = out.index(after: idx) }
        else { break }
      }
      result.append(String(out[idx...]))
    }
    return result.joined(separator: "\n")
  }
}

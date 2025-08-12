import CodeParserCore
import Foundation

public class MarkdownNewlineBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .newline
    else { return false }
    // Determine whether this newline forms a blank line (two consecutive newlines)
    let state = (context.state as? MarkdownConstructState) ?? MarkdownConstructState()
    if context.state == nil { context.state = state }

    // Check previous token
    let prevIsNewline: Bool = {
      if context.consuming == 0 { return false }
      if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
        return prev.element == .newline
      }
      return false
    }()
  // Update state: it's a blank line only if this newline directly follows another
  state.lastWasBlankLine = prevIsNewline
    // A physical newline resets blockquote paragraph split tracking unless it's a quoted blank
    // (quoted blank is handled in Blockquote builder itself)
    state.pendingBlockquoteParagraphSplit = false
    state.prevBlockquoteLineWasBlockStart = false

    context.consuming += 1
    // Pop current to its parent so new blocks will attach at the right level
    context.current = context.current.parent ?? context.current
    return true
  }
}

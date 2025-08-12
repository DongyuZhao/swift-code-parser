import CodeParserCore
import Foundation

public class MarkdownAdmonitionBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      isStartOfLine(context),
      let gt = context.tokens[context.consuming] as? MarkdownToken,
      gt.element == .gt
    else { return false }
    var idx = context.consuming + 1
    // Optional whitespace after '>' (one or more space/tab)
    while idx < context.tokens.count,
      let ws = context.tokens[idx] as? MarkdownToken,
      ws.element == .space || ws.element == .tab
    { idx += 1 }
    guard idx + 3 < context.tokens.count,
      let lb = context.tokens[idx] as? MarkdownToken, lb.element == .leftBracket,
      let ex = context.tokens[idx + 1] as? MarkdownToken, ex.element == .exclamation,
      let text = context.tokens[idx + 2] as? MarkdownToken, text.element == .text,
      let rb = context.tokens[idx + 3] as? MarkdownToken, rb.element == .rightBracket
    else { return false }
    let kind = text.text.lowercased()
    idx += 4

    // Allow optional title or trailing text on the header line (we treat it as no-op here).
    // Consume until end of line.
    guard idx < context.tokens.count else { return false }
    while idx < context.tokens.count,
      let tk = context.tokens[idx] as? MarkdownToken,
      tk.element != .newline
    { idx += 1 }
    // Expect a newline to end the header line
    guard idx < context.tokens.count,
      let nl = context.tokens[idx] as? MarkdownToken,
      nl.element == .newline
    else { return false }
    idx += 1

    // At least one following blockquote content line is required
    guard idx < context.tokens.count,
      isStartOfLine(index: idx, tokens: context.tokens),
      let gt2 = context.tokens[idx] as? MarkdownToken,
      gt2.element == .gt
    else { return false }

    let node = AdmonitionNode(kind: kind)
    let inlineBuilder = MarkdownInlineBuilder()

    // Loop over consecutive lines that continue the same blockquote with '>'
    contentLoop: while idx < context.tokens.count {
      // Start-of-line '>'
      guard isStartOfLine(index: idx, tokens: context.tokens),
        let q = context.tokens[idx] as? MarkdownToken, q.element == .gt
      else { break contentLoop }
      idx += 1
      // Optional whitespace after '>' on content line
      while idx < context.tokens.count,
        let sp = context.tokens[idx] as? MarkdownToken,
        sp.element == .space || sp.element == .tab
      { idx += 1 }

      // Build inline contents for the remainder of this line
      var inlineCtx = CodeConstructContext(
        current: node,
        tokens: context.tokens,
        consuming: idx,
        state: context.state
      )
      _ = inlineBuilder.build(from: &inlineCtx)
      idx = inlineCtx.consuming
      // Consume a trailing newline if present and continue; if not, break
      if idx < context.tokens.count,
        let nlt = context.tokens[idx] as? MarkdownToken,
        nlt.element == .newline
      {
        idx += 1
      } else {
        break
      }
      // Continue the loop; next iteration will verify starting with '>' again
    }

    // Commit consumption and append node once we've captured lines
    context.consuming = idx
    context.current.append(node)
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

  private func isStartOfLine(index: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    if index == 0 { return true }
    if index - 1 < tokens.count,
      let prev = tokens[index - 1] as? MarkdownToken
    {
      return prev.element == .newline
    }
    return false
  }
}

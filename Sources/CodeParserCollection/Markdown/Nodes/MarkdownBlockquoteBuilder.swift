import CodeParserCore
import Foundation

public class MarkdownBlockquoteBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    // Lazy continuation: if at start-of-line, previous sibling is blockquote, and current token does not start another block
    if isStartOfLine(context),
       context.consuming < context.tokens.count,
       let tok = context.tokens[context.consuming] as? MarkdownToken,
       tok.element != .gt,
       let lastBq = context.current.children.last as? BlockquoteNode,
       let lastPara = lastBq.children.last as? ParagraphNode,
       !tok.isLineEnding,
       !tok.canStartBlock {
      // Append this line as lazy continuation to last paragraph
      lastPara.append(LineBreakNode(variant: .soft))
      let temp = ParagraphNode(range: tok.range)
      var inlineCtx = CodeConstructContext(
        current: temp,
        tokens: context.tokens,
        consuming: context.consuming,
        state: context.state
      )
      let inlineBuilder = MarkdownInlineBuilder()
      _ = inlineBuilder.build(from: &inlineCtx)
      context.consuming = inlineCtx.consuming
      for child in temp.children { lastPara.append(child) }
      if context.consuming < context.tokens.count,
         let nl = context.tokens[context.consuming] as? MarkdownToken,
         nl.element == .newline {
        context.consuming += 1
      }
      return true
    }

    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .gt,
      isStartOfLine(context)
    else { return false }
    // Consume '>' marker
    context.consuming += 1
    // Optional leading space after '>'
    if context.consuming < context.tokens.count,
       let space = context.tokens[context.consuming] as? MarkdownToken,
       space.element == .space {
      context.consuming += 1
    }

    // Get or create current blockquote container
    let bq: BlockquoteNode
    if let last = context.current.children.last as? BlockquoteNode {
      bq = last
    } else {
      bq = BlockquoteNode()
      context.current.append(bq)
    }

    // Decide whether to merge into last paragraph
    let lastPara = bq.children.last as? ParagraphNode
    let canMerge: Bool = {
      guard let lp = lastPara else { return false }
      // Blank line detection: previous token (consuming points at first inline token) is newline; if token before that is newline => blank line => no merge
      let prevIndex = context.consuming - 1 // token just before inline content (space or '>')
      // Find the newline immediately preceding '>' marker at start-of-line: it's at prevNewlineIdx
      // We already guaranteed start-of-line, so token at some index before '>' is a newline or start.
      // Simpler: if there are two consecutive newlines before '>' we shouldn't merge.
      var newlineCount = 0
      var scan = prevIndex
      while scan >= 0,
            let tk = context.tokens[scan] as? MarkdownToken,
            tk.element == .newline {
        newlineCount += 1
        scan -= 1
      }
      if newlineCount >= 2 { return false }
      // Also require paragraph not empty
      return !lp.children.isEmpty
    }()

    if canMerge, let paragraph = lastPara {
      // Parse inline for this line and append with soft break
      paragraph.append(LineBreakNode(variant: .soft))
      let temp = ParagraphNode(range: token.range)
      var inlineCtx = CodeConstructContext(
        current: temp,
        tokens: context.tokens,
        consuming: context.consuming,
        state: context.state
      )
      let inlineBuilder = MarkdownInlineBuilder()
      _ = inlineBuilder.build(from: &inlineCtx)
      context.consuming = inlineCtx.consuming
      for child in temp.children { paragraph.append(child) }
    } else {
      // Start a new paragraph
      let paragraph = ParagraphNode(range: token.range)
      var inlineCtx = CodeConstructContext(
        current: paragraph,
        tokens: context.tokens,
        consuming: context.consuming,
        state: context.state
      )
      let inlineBuilder = MarkdownInlineBuilder()
      _ = inlineBuilder.build(from: &inlineCtx)
      context.consuming = inlineCtx.consuming
      bq.append(paragraph)
    }

    // Consume single trailing newline (not blank line) if present
    if context.consuming < context.tokens.count,
       let nl = context.tokens[context.consuming] as? MarkdownToken,
       nl.element == .newline {
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
}

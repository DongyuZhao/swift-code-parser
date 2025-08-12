import CodeParserCore
import Foundation

public class MarkdownBlockquoteBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    let state = (context.state as? MarkdownConstructState) ?? MarkdownConstructState()
    if context.state == nil { context.state = state }

    // Case 1: Lazy continuation line for an open blockquote paragraph
    if isStartOfLine(context),
      context.consuming < context.tokens.count,
      let tok = context.tokens[context.consuming] as? MarkdownToken,
      tok.element != .gt,
      let lastBq = context.current.children.last as? BlockquoteNode,
      let lastPara = lastBq.children.last as? ParagraphNode,
      !tok.isLineEnding
    {
      // Do not lazily continue if a blank line occurred, or a quoted blank requested a split
      if let st = context.state as? MarkdownConstructState {
        if st.lastWasBlankLine || st.pendingBlockquoteParagraphSplit { return false }
      }
      // If the token can start a block, we should terminate lazy continuation
      if tok.canStartBlock { return false }
      // Append this line as lazy continuation to last paragraph
      let before = context.consuming
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
        nl.element == .newline
      {
        context.consuming += 1
      }
      // If no progress was made, back out and let other builders handle this line
      if context.consuming == before { return false }
      return true
    }

    // Case 2: A quoted line starting with '>'
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .gt,
      isStartOfLine(context)
    else { return false }

  // Consume '>' marker and optional single space after it
  context.consuming += 1
    if context.consuming < context.tokens.count,
      let space = context.tokens[context.consuming] as? MarkdownToken,
      space.element == .space
    {
      context.consuming += 1
    }

    // Get or create current blockquote container. If a blank line has just
    // occurred, start a fresh blockquote rather than merging into the last one.
    let bq: BlockquoteNode
    if let st = context.state as? MarkdownConstructState, st.lastWasBlankLine {
      let fresh = BlockquoteNode()
      context.current.append(fresh)
      bq = fresh
      st.lastWasBlankLine = false
    } else if let last = context.current.children.last as? BlockquoteNode {
      bq = last
    } else {
      bq = BlockquoteNode()
      context.current.append(bq)
    }

    // Quoted blank line: if the next token is newline or EOF, mark paragraph split and consume newline
    if context.consuming < context.tokens.count,
      let tk = context.tokens[context.consuming] as? MarkdownToken,
      (tk.element == .newline || tk.element == .eof)
    {
      state.pendingBlockquoteParagraphSplit = true
      if tk.element == .newline {
        let before = context.consuming
        context.consuming += 1
        if context.consuming == before { return false }
      }
      // Stay inside same blockquote, do not create a paragraph
      return true
    }

    // Determine whether to merge with previous paragraph inside blockquote
    let lastPara = bq.children.last as? ParagraphNode
    var mergeWithPrevious = false
    if let _ = lastPara, !state.pendingBlockquoteParagraphSplit, !state.prevBlockquoteLineWasBlockStart {
      mergeWithPrevious = true
    }

    // If next token can start a block, avoid merging (it should be its own block normally,
    // but our blockquote currently only supports paragraph content; still, do not merge)
    if context.consuming < context.tokens.count,
      let next = context.tokens[context.consuming] as? MarkdownToken,
      next.canStartBlock
    {
      mergeWithPrevious = false
      state.prevBlockquoteLineWasBlockStart = true
    } else {
      state.prevBlockquoteLineWasBlockStart = false
    }

    if mergeWithPrevious, let paragraph = lastPara {
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
      let madeProgress = inlineCtx.consuming > context.consuming
      context.consuming = inlineCtx.consuming
      for child in temp.children { paragraph.append(child) }
      if !madeProgress {
        // No inline content consumed; treat consecutive spaces as empty and consume them/newline
        _ = consumeLeadingSpaces(&context)
        if context.consuming < context.tokens.count,
          let nl = context.tokens[context.consuming] as? MarkdownToken,
          nl.element == .newline
        {
          context.consuming += 1
        }
        return true
      }
    } else {
      // Start a new paragraph within blockquote
      let paragraph = ParagraphNode(range: token.range)
      var inlineCtx = CodeConstructContext(
        current: paragraph,
        tokens: context.tokens,
        consuming: context.consuming,
        state: context.state
      )
      let inlineBuilder = MarkdownInlineBuilder()
      _ = inlineBuilder.build(from: &inlineCtx)
      let madeProgress = inlineCtx.consuming > context.consuming
      context.consuming = inlineCtx.consuming
      bq.append(paragraph)
      state.pendingBlockquoteParagraphSplit = false
      if !madeProgress {
        // If only spaces remain before newline, treat as quoted blank line: remove empty paragraph
        let consumedSpaces = consumeLeadingSpaces(&context)
        if context.consuming < context.tokens.count,
          let nl = context.tokens[context.consuming] as? MarkdownToken,
          nl.element == .newline
        {
          context.consuming += 1
          // Remove the empty paragraph we just appended, and mark paragraph split
          if paragraph.children.isEmpty,
            let last = bq.children.last, last === paragraph
          {
            _ = bq.children.popLast()
          }
          state.pendingBlockquoteParagraphSplit = true
          return true
        } else if consumedSpaces {
          // We consumed some spaces as contentless; to avoid stalling, append a single space
          paragraph.append(TextNode(content: " "))
        }
      }
    }

    // Trailing newline after quoted content
    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
  return true
  }
}

extension MarkdownBlockquoteBuilder {
  /// Consume consecutive spaces/tabs from the current position. Returns true if any were consumed.
  fileprivate func consumeLeadingSpaces(
    _ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    var consumed = false
    while context.consuming < context.tokens.count,
      let sp = context.tokens[context.consuming] as? MarkdownToken,
      (sp.element == .space || sp.element == .tab)
    {
      context.consuming += 1
      consumed = true
    }
    return consumed
  }
  fileprivate func isStartOfLine(
    _ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    if context.consuming == 0 { return true }
    if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
      return prev.element == .newline
    }
    return false
  }
}

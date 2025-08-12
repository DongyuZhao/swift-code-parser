import CodeParserCore
import Foundation

public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element != .newline,
      token.element != .eof
    else { return false }
  let state = (context.state as? MarkdownConstructState) ?? MarkdownConstructState()
  if context.state == nil { context.state = state }
    // Determine target for the paragraph. Normally it's the current node, but
    // for list item continuation paragraphs we need to attach to the last list item.
    var target: CodeNode<MarkdownNodeElement> = context.current
    if context.current.element == .orderedList || context.current.element == .unorderedList {
      if let lastItem = context.current.children.last {
        // Peek ahead (skip leading spaces) to detect if this line starts a new list marker.
        var idx = context.consuming
        var spaceCount = 0
        while idx < context.tokens.count,
          let sp = context.tokens[idx] as? MarkdownToken,
          sp.element == .space
        {
          spaceCount += 1
          idx += 1
        }
        // Detect ordered list marker: number + dot + space
        var isNewListMarker = false
        if idx < context.tokens.count,
          let num = context.tokens[idx] as? MarkdownToken,
          num.element == .number
        {
          if idx + 2 < context.tokens.count,
            let dot = context.tokens[idx + 1] as? MarkdownToken,
            dot.element == .dot,
            let sp = context.tokens[idx + 2] as? MarkdownToken,
            sp.element == .space
          {
            isNewListMarker = true
          }
        }
        // Detect unordered list marker: -, +, * followed by space
        if !isNewListMarker,
          idx < context.tokens.count,
          let bullet = context.tokens[idx] as? MarkdownToken,
          bullet.element == .dash || bullet.element == .plus || bullet.element == .asterisk
        {
          if idx + 1 < context.tokens.count,
            let sp = context.tokens[idx + 1] as? MarkdownToken,
            sp.element == .space
          {
            isNewListMarker = true
          }
        }
        // CommonMark: A blank line then indented content (at least one space) belongs to the list item.
        if !isNewListMarker && spaceCount > 0, let listItem = lastItem as? MarkdownNodeBase,
          listItem.element == .listItem
        {
          target = listItem
        }
      }
    }

    // Skip leading indentation spaces for continuation paragraphs inside list items
    let isListItemTarget = target.element == .listItem
    if isListItemTarget {
      while context.consuming < context.tokens.count,
        let sp = context.tokens[context.consuming] as? MarkdownToken,
        sp.element == .space
      { context.consuming += 1 }
      // Refresh token after trimming
      guard context.consuming < context.tokens.count,
        let _ = context.tokens[context.consuming] as? MarkdownToken
      else { return false }
    }

    let node = ParagraphNode(range: token.range)
    var inlineCtx = CodeConstructContext(
      current: node,
      tokens: context.tokens,
      consuming: context.consuming,
      state: context.state
    )
    let inlineBuilder = MarkdownInlineBuilder()
    _ = inlineBuilder.build(from: &inlineCtx)
    context.consuming = inlineCtx.consuming

    // Early Setext heading detection (before line merging). Only when paragraph is not list item continuation.
    if target.element != .listItem,
      context.consuming < context.tokens.count,
      let nlTok = context.tokens[context.consuming] as? MarkdownToken,
      nlTok.element == .newline
    {
      // Look ahead to gather underline line tokens
      var idx = context.consuming + 1
      var underline: [MarkdownToken] = []
      while idx < context.tokens.count,
        let t = context.tokens[idx] as? MarkdownToken,
        t.element != .newline, t.element != .eof
      {
        underline.append(t)
        idx += 1
      }
      if !underline.isEmpty {
        let hasEquals = underline.contains { $0.element == .equals }
        let hasDashes = underline.contains { $0.element == .dash }
        if hasEquals != hasDashes {  // not mixed
          let invalid = underline.contains { tok in
            !(tok.element == .space || tok.element == .equals || tok.element == .dash)
          }
          if !invalid {
            let level = hasEquals ? 1 : 2
            // Replace paragraph with header
            let header = HeaderNode(level: level)
            for child in node.children { header.append(child) }
            target.append(header)
            context.current = target
            // Advance consuming over newline + underline + optional trailing newline
            context.consuming = idx
            if context.consuming < context.tokens.count,
              let endNl = context.tokens[context.consuming] as? MarkdownToken,
              endNl.element == .newline
            {
              context.consuming += 1
            }
            // Consume terminator newline if present
            if context.consuming < context.tokens.count,
              let termNl = context.tokens[context.consuming] as? MarkdownToken,
              termNl.element == .newline
            {
              context.consuming += 1
            }
            return true
          }
        }
      }
    }

    // If a previous quoted blank requested a paragraph split inside a blockquote, honor it
    // by not merging the upcoming line into the previous paragraph. We do this by clearing
    // the flag here and simply letting this paragraph start fresh.
    if state.pendingBlockquoteParagraphSplit {
      state.pendingBlockquoteParagraphSplit = false
    }

    // Merge successive non-blank lines into same paragraph (soft line breaks)
    // Stop on blank line (double newline), EOF, or a token that can start a new block.
    lineJoin: while context.consuming < context.tokens.count {
      guard let nl = context.tokens[context.consuming] as? MarkdownToken, nl.element == .newline
      else { break }
      // Peek next token to decide termination
      if context.consuming + 1 < context.tokens.count,
        let next = context.tokens[context.consuming + 1] as? MarkdownToken
      {
        // Blank line => terminate paragraph (consume one newline leaving following newline for outer loop to skip)
        if next.element == .newline { break }
        // End of file after newline -> do not merge as soft break
        if next.element == .eof { break }
        // Block-starting token (e.g., heading, list, blockquote, code fence) should end paragraph
        if next.canStartBlock { break }
      }
      // We will merge the next line into same paragraph
      // Determine hard vs soft line break based on trailing spaces or backslash before newline
      var isHard = false
      if let last = node.children.last as? TextNode, !last.content.isEmpty {
        if last.content.hasSuffix("\\") {  // backslash hard break
          isHard = true
          last.content.removeLast()
        } else {
          // Count trailing spaces
          var spaceCount = 0
          var i = last.content.endIndex
          while i > last.content.startIndex {
            let prev = last.content.index(before: i)
            if last.content[prev] == " " {
              spaceCount += 1
              i = prev
            } else {
              break
            }
          }
          if spaceCount >= 2 {  // hard break
            isHard = true
            // trim trailing spaces used for hard break
            last.content = String(last.content.dropLast(spaceCount))
          }
        }
      }
      // Consume newline
      context.consuming += 1
      if isHard {
        node.append(LineBreakNode(variant: .hard))
      } else {
        // For soft break, collapse to a single space if last text node does not already end with space
        if let last = node.children.last as? TextNode {
          if !last.content.hasSuffix(" ") { last.content += " " }
        } else {
          node.append(TextNode(content: " "))
        }
      }
      // Parse next line inline content and append
      var moreCtx = CodeConstructContext(
        current: node,
        tokens: context.tokens,
        consuming: context.consuming,
        state: context.state
      )
      _ = inlineBuilder.build(from: &moreCtx)
      // If no progress, break to avoid infinite loop
      if moreCtx.consuming == context.consuming { break lineJoin }
      context.consuming = moreCtx.consuming
    }

    // Merge following soft-wrapped lines (single newline + indentation) into same paragraph for list items
    if isListItemTarget {
      lineLoop: while context.consuming < context.tokens.count {
        guard let nl = context.tokens[context.consuming] as? MarkdownToken, nl.element == .newline
        else { break }
        // Look ahead
        var look = context.consuming + 1
        // Blank line (double newline) terminates paragraph
        if look < context.tokens.count, let nextNl = context.tokens[look] as? MarkdownToken,
          nextNl.element == .newline
        {
          break
        }
        // Consume newline
        context.consuming += 1
        // Collect indentation spaces/tabs
        while look < context.tokens.count,
          let sp = context.tokens[look] as? MarkdownToken,
          sp.element == .space || sp.element == .tab
        { look += 1 }
        // Detect if next sequence starts a new list marker
        let markerIdx = look
        var isNewListMarker = false
        if markerIdx < context.tokens.count, let tk = context.tokens[markerIdx] as? MarkdownToken {
          switch tk.element {
          case .number:
            if markerIdx + 2 < context.tokens.count,
              let dot = context.tokens[markerIdx + 1] as? MarkdownToken, dot.element == .dot,
              let sp = context.tokens[markerIdx + 2] as? MarkdownToken, sp.element == .space
            {
              isNewListMarker = true
            }
          case .dash, .plus, .asterisk:
            if markerIdx + 1 < context.tokens.count,
              let sp = context.tokens[markerIdx + 1] as? MarkdownToken, sp.element == .space
            {
              isNewListMarker = true
            }
          default: break
          }
        }
        if isNewListMarker { break }
        // If next is EOF or newline (blank), stop
        if markerIdx >= context.tokens.count { break }
        if let nextTk = context.tokens[markerIdx] as? MarkdownToken, nextTk.element == .newline {
          break
        }
        // Advance consuming to after indentation
        context.consuming = look
        // Parse additional inline content into the same paragraph
        var moreCtx = CodeConstructContext(
          current: node,
          tokens: context.tokens,
          consuming: context.consuming,
          state: context.state
        )
        _ = inlineBuilder.build(from: &moreCtx)
        // No progress means bail to avoid infinite loop
        if moreCtx.consuming == context.consuming { break lineLoop }
        context.consuming = moreCtx.consuming
      }
    }

    // Remove empty paragraphs: only whitespace text nodes OR no children
    let hasNonText = node.children.contains { !($0 is TextNode) }
    if !hasNonText {
      let textContents = node.children.compactMap { ($0 as? TextNode)?.content }.joined()
      if textContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
    }

    // Trim leading indentation spaces in first text node of list item continuation paragraphs
    if isListItemTarget, let first = node.children.first as? TextNode {
      // CommonMark allows up to 3 spaces indentation for a paragraph continuation
      let original = first.content
      let trimmed = original.replacingOccurrences(
        of: "^ {1,3}", with: "", options: .regularExpression)
      first.content = trimmed
    }

    target.append(node)
    context.current = target

    // Setext heading detection (only when paragraph is a direct child of container, not list item continuation)
    if target.element != .listItem {  // list item continuation paragraphs shouldn't form setext headings
      if context.consuming < context.tokens.count,
        let nl = context.tokens[context.consuming] as? MarkdownToken, nl.element == .newline
      {
        var idx = context.consuming + 1
        var underline: [MarkdownToken] = []
        while idx < context.tokens.count,
          let t = context.tokens[idx] as? MarkdownToken,
          t.element != .newline,
          t.element != .eof
        {
          underline.append(t)
          idx += 1
        }
        if !underline.isEmpty {
          let hasEquals = underline.contains { $0.element == .equals }
          let hasDashes = underline.contains { $0.element == .dash }
          // Must not mix '=' and '-' per spec for simple detection (mixed would be thematic break or invalid)
          if hasEquals != hasDashes {  // exactly one kind
            // Ensure only spaces and that marker type present
            let invalid = underline.contains { tok in
              !(tok.element == .space || tok.element == .equals || tok.element == .dash)
            }
            if !invalid {
              // Determine heading level
              let level = hasEquals ? 1 : 2
              // Consume underline line including trailing newline (if present)
              if idx < context.tokens.count, let endNl = context.tokens[idx] as? MarkdownToken,
                endNl.element == .newline
              {
                // We'll consume both the separating newline and underline line newline
                // current position at first newline before underline; keep it to allow header replacing paragraph position
              }
              // Remove paragraph we just appended and replace with header
              if let paraIndex = target.children.lastIndex(where: { $0 === node }) {
                let header = HeaderNode(level: level)
                for child in node.children { header.append(child) }
                target.children[paraIndex] = header
              }
              // Advance consuming pointer over separating newline + underline line + optional ending newline
              // Currently context.consuming at underline separating newline
              context.consuming = idx
              if context.consuming < context.tokens.count,
                let endNl = context.tokens[context.consuming] as? MarkdownToken,
                endNl.element == .newline
              {
                context.consuming += 1
              }
            }
          }
        }
      }
    }

    // Consume a single trailing newline (paragraph terminator) if present
    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
    return true
  }
}

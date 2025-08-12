import CodeParserCore
import Foundation

public class MarkdownHeadingBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    // Must be start of a line (or after newline)
    guard isStartOfLine(context) else { return false }
    guard context.consuming < context.tokens.count else { return false }

    // Allow up to 3 leading spaces before ATX heading marker
    var idx = context.consuming
    var leadingSpaces = 0
    while idx < context.tokens.count,
      let sp = context.tokens[idx] as? MarkdownToken,
      sp.element == .space,
      leadingSpaces < 3
    {
      leadingSpaces += 1
      idx += 1
    }

    // Count 1..6 leading '#'
    var level = 0
    var hashIdx = idx
    while hashIdx < context.tokens.count,
      let t = context.tokens[hashIdx] as? MarkdownToken,
      t.element == .hash,
      level < 6
    {
      level += 1
      hashIdx += 1
    }
    // Not a heading if no '#' or more than 6 or first non-space isn't '#'
    guard level > 0 else { return false }
    // If we hit 6 '#' but next is also '#', then it's 7+ -> not a heading
    if level == 6,
      hashIdx < context.tokens.count,
      let next = context.tokens[hashIdx] as? MarkdownToken,
      next.element == .hash
    { return false }

    // After hashes: must be space, or end-of-line (empty heading)
    var contentStart = hashIdx
    if contentStart < context.tokens.count,
      let next = context.tokens[contentStart] as? MarkdownToken
    {
      if next.element == .space {
        contentStart += 1
      } else if next.element == .newline || next.element == .eof {
        // empty heading, contentStart stays to allow empty inline
      } else {
        // No space and not EOL => not a heading (e.g. #hashtag)
        return false
      }
    }

    // All good: move consuming to the start of content
    context.consuming = contentStart
    let node = HeaderNode(level: level)
    var inlineCtx = CodeConstructContext(
      current: node,
      tokens: context.tokens,
      consuming: context.consuming,
      state: context.state
    )
    let inlineBuilder = MarkdownInlineBuilder()
    _ = inlineBuilder.build(from: &inlineCtx)
    context.consuming = inlineCtx.consuming
  // Determine end of line to evaluate optional closing sequence " #+" and trailing spaces
    var lineEnd = context.consuming
    if lineEnd < context.tokens.count,
      let t = context.tokens[lineEnd] as? MarkdownToken,
      t.element == .newline
    {
      // lineEnd points at newline token; set logical end to previous token index
      lineEnd = lineEnd - 1
    } else {
      lineEnd = lineEnd - 1
    }
    // Scan backwards over possible trailing spaces and hashes to detect valid closing sequence
    func hasValidClosingSequence() -> Int {
      guard lineEnd >= 0 else { return (0) }
      var i = lineEnd
      var trailingSpaces = 0
      // Collect trailing spaces
      while i >= 0, let tk = context.tokens[i] as? MarkdownToken, tk.element == .space {
        trailingSpaces += 1
        i -= 1
      }
      // Collect trailing hashes
      var hashes = 0
      while i >= 0, let tk = context.tokens[i] as? MarkdownToken, tk.element == .hash {
        hashes += 1
        i -= 1
      }
      guard hashes > 0 else { return (0) }
      // The token before hash run must be a space; otherwise not a closing sequence
      guard i >= 0, let prev = context.tokens[i] as? MarkdownToken, prev.element == .space else {
        return (0)
      }
      // Also ensure the first hash wasn't escaped: immediate token before the first '#' cannot be a backslash
      // i currently points at the space before hash run; so the token just before space is irrelevant for escape check
      // For cases like " #\\##" or " \\###", the backslash breaks either the contiguous run or the preceding-space condition above
      // Return only preceding space + hashes; trailing spaces are trimmed separately from the text content
      return (hashes + 1)
    }
    let toTrim = hasValidClosingSequence()
    // Trim leading spaces from first text node (content should not start with spaces)
    if let firstText = node.children.first(where: { $0 is TextNode }) as? TextNode,
       !firstText.content.isEmpty {
      firstText.content = firstText.content.replacingOccurrences(of: "^ +", with: "", options: .regularExpression)
    }
    // Remove trailing spaces always; if a valid closing sequence exists, also remove preceding space + hashes
    if let last = node.children.last as? TextNode, !last.content.isEmpty {
      var s = last.content
      // First, trim trailing spaces
      while s.last == " " { s.removeLast() }
      if toTrim > 0 {
        // Drop (space + hashes) from the end
        var dropped = 0
        while dropped < toTrim, !s.isEmpty {
          s.removeLast()
          dropped += 1
        }
        // Finally, trim any residual trailing spaces
        while s.last == " " { s.removeLast() }
      }
      last.content = s
    }
    context.current.append(node)

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
}

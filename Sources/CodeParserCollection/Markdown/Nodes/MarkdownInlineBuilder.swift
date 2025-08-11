import CodeParserCore
import Foundation

/// Inline node builder that parses Markdown inline elements.
/// Each inline element is handled by a dedicated sub-builder and a composite
/// builder loops through them to construct the result.
public class MarkdownInlineBuilder: CodeNodeBuilder {
  private let stopAt: Set<MarkdownTokenElement>

  public init(stopAt: Set<MarkdownTokenElement> = [.newline, .eof]) {
    self.stopAt = stopAt
  }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    let start = context.consuming
    let nodes = Self.parseInline(&context, stopAt: stopAt)
    for node in nodes { context.current.append(node) }
    return context.consuming > start
  }

  /// Parse inline content until one of the `stopAt` tokens is encountered.
  /// - Parameters:
  ///   - context: Construction context providing tokens and current state.
  ///   - stopAt: Tokens that terminate inline parsing.
  /// - Returns: Array of parsed inline nodes.
  private static func parseInline(
    _ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
    stopAt: Set<MarkdownTokenElement>
  ) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var delimiters: [Delimiter] = []

    let builders: [InlineBuilder] = [
      EmphasisBuilder(),
      InlineCodeBuilder(),
      FormulaBuilder(),
      HTMLBuilder(),
      ImageBuilder(),
      LinkBuilder(),
      AutolinkBuilder(),
      TextBuilder(),
    ]

    outer: while context.consuming < context.tokens.count {
      guard let token = context.tokens[context.consuming] as? MarkdownToken else { break }
      if stopAt.contains(token.element) { break }

      for builder in builders {
        if builder.build(from: &context, nodes: &nodes, delimiters: &delimiters) {
          continue outer
        }
      }

      // If no builder handled the token, advance to avoid infinite loop
      context.consuming += 1
    }

    return nodes
  }

  private struct Delimiter {
    var marker: MarkdownTokenElement
    var count: Int
    var index: Int
  }

  /// Protocol for inline node builders.
  private protocol InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool
  }

  // MARK: - Individual inline builders
  private struct EmphasisBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .asterisk || token.element == .underscore || token.element == .tilde
      else { return false }

      let marker = token.element
      var count = 0
      while context.consuming < context.tokens.count,
        let t = context.tokens[context.consuming] as? MarkdownToken,
        t.element == marker
      {
        count += 1
        context.consuming += 1
      }

      // Basic flanking heuristic for single delimiter runs to prevent premature closing
      if (marker == .asterisk || marker == .underscore) && count == 1 {
        let runStart = context.consuming - count
        let prevToken = runStart > 0 ? context.tokens[runStart - 1] as? MarkdownToken : nil
        let nextToken = context.consuming < context.tokens.count ? context.tokens[context.consuming] as? MarkdownToken : nil
        let prevIsWhitespace = prevToken?.isWhitespace ?? true
        let nextIsWhitespace = nextToken?.isWhitespace ?? true
        let nextIsPunct = nextToken?.isPunctuation ?? false
        let prevIsPunct = prevToken?.isPunctuation ?? false
        let isRightFlanking = !prevIsWhitespace && (nextIsWhitespace || nextIsPunct || nextToken == nil)
        let isLeftFlanking = !nextIsWhitespace && (prevIsWhitespace || prevIsPunct || prevToken == nil)
        if isLeftFlanking && !isRightFlanking {
          // Treat as pure opener: push delimiter stack entry without attempting closure
          nodes.append(TextNode(content: String(marker.rawValue)))
          delimiters.append(Delimiter(marker: marker, count: 1, index: nodes.count - 1))
          return true
        }
      }

      // Intraword underscore rule (CommonMark): runs of '_' inside a word should be literal
      if marker == .underscore {
        let prevAlphaNum: Bool = {
          if context.consuming - count > 0, let prev = context.tokens[context.consuming - count - 1] as? MarkdownToken, let ch = prev.text.last { return ch.isLetter || ch.isNumber }
          return false
        }()
        let nextAlphaNum: Bool = {
          if context.consuming < context.tokens.count, let next = context.tokens[context.consuming] as? MarkdownToken, let ch = next.text.first { return ch.isLetter || ch.isNumber }
          return false
        }()
        if prevAlphaNum && nextAlphaNum {
          // Treat as plain text (merge if possible)
          let textRun = String(repeating: "_", count: count)
          if let last = nodes.last as? TextNode, !delimiters.contains(where: { $0.index == nodes.count - 1 }) {
            last.content += textRun
          } else {
            nodes.append(TextNode(content: textRun))
          }
          return true
        }
      }

      // Special handling for complex asterisk runs to satisfy nested emphasis expectations.
      if marker == .asterisk {
        // Decompose **** into two strong delimiters (outer then inner)
        if count >= 4 {
          var remaining = count
            while remaining >= 2 {
              // append text node for '**'
              let text = "**"
              nodes.append(TextNode(content: text))
              delimiters.append(Delimiter(marker: marker, count: 2, index: nodes.count - 1))
              remaining -= 2
            }
            if remaining == 1 { // leftover single emphasis
              nodes.append(TextNode(content: "*"))
              delimiters.append(Delimiter(marker: marker, count: 1, index: nodes.count - 1))
            }
            return true
        } else if count == 3 {
          // Peek ahead to decide ordering of '**' + '*' vs '*' + '**'
          var firstSinglePos: Int? = nil
          var firstDoublePos: Int? = nil
          var i = context.consuming
          while i < context.tokens.count {
            guard let at = context.tokens[i] as? MarkdownToken else { break }
            if at.element == .newline || at.element == .eof { break }
            if at.element == .asterisk {
              var run = 0
              var j = i
              while j < context.tokens.count, let tt = context.tokens[j] as? MarkdownToken, tt.element == .asterisk { run += 1; j += 1 }
              if run >= 2 && firstDoublePos == nil { firstDoublePos = i }
              if run == 1 && firstSinglePos == nil { firstSinglePos = i }
              if firstSinglePos != nil && firstDoublePos != nil { break }
              i = j
              continue
            }
            i += 1
          }
          // If single appears before double, open strong then emphasis ( ** then * ) ; else emphasis then strong
          let singleBeforeDouble: Bool
          if let s = firstSinglePos, let d = firstDoublePos { singleBeforeDouble = s < d } else if firstSinglePos != nil { singleBeforeDouble = true } else { singleBeforeDouble = false }
          if singleBeforeDouble {
            // '**' then '*'
            nodes.append(TextNode(content: "**"))
            delimiters.append(Delimiter(marker: marker, count: 2, index: nodes.count - 1))
            nodes.append(TextNode(content: "*"))
            delimiters.append(Delimiter(marker: marker, count: 1, index: nodes.count - 1))
          } else {
            // '*' then '**'
            nodes.append(TextNode(content: "*"))
            delimiters.append(Delimiter(marker: marker, count: 1, index: nodes.count - 1))
            nodes.append(TextNode(content: "**"))
            delimiters.append(Delimiter(marker: marker, count: 2, index: nodes.count - 1))
          }
          return true
        }
      }
      if marker == .tilde && count < 2 {
        // Single tilde is literal; merge into previous text node if possible
        if let last = nodes.last as? TextNode, !delimiters.contains(where: { $0.index == nodes.count - 1 }) {
          last.content += String(repeating: "~", count: count)
        } else {
          let text = String(repeating: "~", count: count)
          nodes.append(TextNode(content: text))
        }
      } else {
        handleDelimiter(marker: marker, count: count, nodes: &nodes, stack: &delimiters)
      }
      return true
    }
  }

  private struct InlineCodeBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .inlineCode
      else { return false }

      nodes.append(InlineCodeNode(code: trimBackticks(token.text)))
      context.consuming += 1
      return true
    }
  }

  private struct FormulaBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken
      else { return false }

      // Inline $...$
      if token.element == .text, token.text == "$" {
        let startIndex = context.consuming
        var i = startIndex + 1
        var closeAt: Int? = nil
        var valid = true
        // $ must not be followed by whitespace; and closing $ must not be preceded by whitespace
        if i < context.tokens.count, let t = context.tokens[i] as? MarkdownToken,
          t.isWhitespace
        { valid = false }
        while valid && i < context.tokens.count {
          guard let t = context.tokens[i] as? MarkdownToken else { break }
          if t.element == .text && t.text == "$" {
            if i > startIndex + 1,
              let prev = context.tokens[i - 1] as? MarkdownToken
            {
              if prev.element == .backslash {
                // escaped $, treat as literal and continue scanning
                i += 1
                continue
              }
              if !prev.isWhitespace {
                closeAt = i + 1
                break
              } else {
                valid = false
                break
              }
            } else {
              valid = false
              break
            }
          }
          if t.element == .newline { valid = false; break }
          i += 1
        }
        if valid, let end = closeAt {
          let raw = joinText(context.tokens, from: startIndex, to: end)
          context.consuming = end
          nodes.append(FormulaNode(expression: trimFormula(raw)))
          return true
        }
        return false
      }

      // Inline \(...\)
      if token.element == .backslash,
        context.consuming + 1 < context.tokens.count,
        let lp = context.tokens[context.consuming + 1] as? MarkdownToken,
        lp.element == .leftParen
      {
        let startIndex = context.consuming
        var i = startIndex + 2
        var closeAt: Int? = nil
        while i < context.tokens.count {
          guard let t = context.tokens[i] as? MarkdownToken else { break }
          if t.element == .backslash,
            i + 1 < context.tokens.count,
            let rp = context.tokens[i + 1] as? MarkdownToken, rp.element == .rightParen
          {
            closeAt = i + 2
            break
          }
          if t.element == .newline { break }
          i += 1
        }
        if let end = closeAt {
          let raw = joinText(context.tokens, from: startIndex, to: end)
          context.consuming = end
          // keep raw for backslash-variant (tests expect delimiters retained)
          nodes.append(FormulaNode(expression: raw))
          return true
        }
        return false
      }

      return false
    }
  }

  private struct HTMLBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .htmlTag || token.element == .htmlBlock
          || token.element == .htmlUnclosedBlock || token.element == .htmlEntity
      else { return false }

      nodes.append(HTMLNode(content: token.text))
      context.consuming += 1
      return true
    }
  }

  private struct ImageBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .exclamation
      else { return false }

      if let image = parseImage(&context) {
        nodes.append(image)
      } else {
        let shouldMerge: Bool
        if let lastIndex = nodes.indices.last,
          let _ = nodes[lastIndex] as? TextNode,
          !delimiters.contains(where: { $0.index == lastIndex })
        {
          shouldMerge = true
        } else {
          shouldMerge = false
        }

        if shouldMerge, let last = nodes.last as? TextNode {
          last.content += token.text
        } else {
          nodes.append(TextNode(content: token.text))
        }
        context.consuming += 1
      }
      return true
    }
  }

  private struct LinkBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .leftBracket
      else { return false }

      if let link = parseLinkOrFootnote(&context) {
        nodes.append(link)
      } else {
        nodes.append(TextNode(content: token.text))
        context.consuming += 1
      }
      return true
    }
  }

  private struct AutolinkBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken,
        token.element == .autolink || token.element == .url
      else { return false }

      let url = trimAutolink(token.text)
      let link = LinkNode(url: url, title: url)
      nodes.append(link)
      context.consuming += 1
      return true
    }
  }

  private struct TextBuilder: InlineBuilder {
    func build(
      from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
      nodes: inout [MarkdownNodeBase],
      delimiters: inout [Delimiter]
    ) -> Bool {
      guard context.consuming < context.tokens.count,
        let token = context.tokens[context.consuming] as? MarkdownToken
      else { return false }

      let shouldMerge: Bool
      if let lastIndex = nodes.indices.last,
        let _ = nodes[lastIndex] as? TextNode,
        !delimiters.contains(where: { $0.index == lastIndex })
      {
        shouldMerge = true
      } else {
        shouldMerge = false
      }

      if shouldMerge, let last = nodes.last as? TextNode {
        last.content += token.text
      } else {
        nodes.append(TextNode(content: token.text))
      }
      context.consuming += 1
      return true
    }
  }

  // MARK: - Shared helpers
  private static func handleDelimiter(
    marker: MarkdownTokenElement,
    count: Int,
    nodes: inout [MarkdownNodeBase],
    stack: inout [Delimiter]
  ) {
    var remaining = count

    while remaining > 0,
      let openIdx = stack.lastIndex(where: { $0.marker == marker && $0.count <= remaining })
    {
      let open = stack.remove(at: openIdx)
      var closeCount = open.count
      if marker == .tilde {
        guard open.count >= 2 && remaining >= 2 else {
          stack.append(open)
          break
        }
        closeCount = 2
      }

      let start = open.index + 1
      let removedCount = nodes.count - open.index
      let content = Array(nodes[start..<nodes.count])
      nodes.removeSubrange(open.index..<nodes.count)
      for i in 0..<stack.count {
        if stack[i].index >= open.index {
          stack[i].index -= removedCount - 1
        }
      }

      let node: MarkdownNodeBase
      if marker == .tilde {
        node = StrikeNode(content: "")
      } else {
        node = (closeCount >= 2) ? StrongNode(content: "") : EmphasisNode(content: "")
      }
      for child in content { node.append(child) }
      nodes.append(node)

      remaining -= closeCount
    }

    if remaining > 0 {
      let text = String(repeating: marker.rawValue, count: remaining)
      nodes.append(TextNode(content: text))
      stack.append(Delimiter(marker: marker, count: remaining, index: nodes.count - 1))
    }
  }

  private static func parseLinkOrFootnote(
    _ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    let start = context.consuming
    context.consuming += 1
    // Footnote reference [^id] or citation [@id]
    if context.consuming < context.tokens.count,
      let caret = context.tokens[context.consuming] as? MarkdownToken,
      caret.element == .caret
    {
      context.consuming += 1
      var ident = ""
      while context.consuming < context.tokens.count,
        let t = context.tokens[context.consuming] as? MarkdownToken,
        t.element != .rightBracket
      {
        ident += t.text
        context.consuming += 1
      }
      guard context.consuming < context.tokens.count,
        let rb = context.tokens[context.consuming] as? MarkdownToken,
        rb.element == .rightBracket
      else {
        context.consuming = start
        return nil
      }
      context.consuming += 1
      return FootnoteReferenceNode(identifier: ident)
    } else if context.consuming < context.tokens.count,
      let at = context.tokens[context.consuming] as? MarkdownToken,
      at.element == .atSign
    {
      context.consuming += 1
      var ident = ""
      while context.consuming < context.tokens.count,
        let t = context.tokens[context.consuming] as? MarkdownToken,
        t.element != .rightBracket
      {
        ident += t.text
        context.consuming += 1
      }
      guard context.consuming < context.tokens.count,
        let rb = context.tokens[context.consuming] as? MarkdownToken,
        rb.element == .rightBracket
      else {
        context.consuming = start
        return nil
      }
      context.consuming += 1
      return CitationReferenceNode(identifier: ident)
    }

    let textNodes = parseInline(&context, stopAt: [.rightBracket])
    guard context.consuming < context.tokens.count,
      let rb = context.tokens[context.consuming] as? MarkdownToken,
      rb.element == .rightBracket
    else {
      context.consuming = start
      return nil
    }
    context.consuming += 1

    // Inline link [text](url)
    if context.consuming < context.tokens.count,
      let lp = context.tokens[context.consuming] as? MarkdownToken,
      lp.element == .leftParen
    {
      context.consuming += 1
      var url = ""
      while context.consuming < context.tokens.count,
        let t = context.tokens[context.consuming] as? MarkdownToken,
        t.element != .rightParen
      {
        url += t.text
        context.consuming += 1
      }
      guard context.consuming < context.tokens.count,
        let rp = context.tokens[context.consuming] as? MarkdownToken,
        rp.element == .rightParen
      else {
        context.consuming = start
        return nil
      }
      context.consuming += 1
      let link = LinkNode(url: url, title: "")
      for child in textNodes { link.append(child) }
      return link
    }

    // Reference link [text][id]
    if context.consuming < context.tokens.count,
      let lb = context.tokens[context.consuming] as? MarkdownToken,
      lb.element == .leftBracket
    {
      context.consuming += 1
      var id = ""
      while context.consuming < context.tokens.count,
        let t = context.tokens[context.consuming] as? MarkdownToken,
        t.element != .rightBracket
      {
        id += t.text
        context.consuming += 1
      }
      guard context.consuming < context.tokens.count,
        let rb2 = context.tokens[context.consuming] as? MarkdownToken,
        rb2.element == .rightBracket
      else {
        context.consuming = start
        return nil
      }
      context.consuming += 1
      let ref = ReferenceNode(identifier: id, url: "", title: "")
      for child in textNodes { ref.append(child) }
      return ref
    }

    context.consuming = start
    return nil
  }

  private static func parseImage(
    _ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    guard context.consuming + 1 < context.tokens.count,
      let lb = context.tokens[context.consuming + 1] as? MarkdownToken,
      lb.element == .leftBracket
    else { return nil }
    context.consuming += 2
    let altNodes = parseInline(&context, stopAt: [.rightBracket])
    guard context.consuming < context.tokens.count,
      let rb = context.tokens[context.consuming] as? MarkdownToken,
      rb.element == .rightBracket
    else {
      context.consuming -= 2
      return nil
    }
    context.consuming += 1
    guard context.consuming < context.tokens.count,
      let lp = context.tokens[context.consuming] as? MarkdownToken,
      lp.element == .leftParen
    else {
      context.consuming -= 3
      return nil
    }
    context.consuming += 1
    var url = ""
    while context.consuming < context.tokens.count,
      let t = context.tokens[context.consuming] as? MarkdownToken,
      t.element != .rightParen
    {
      url += t.text
      context.consuming += 1
    }
    guard context.consuming < context.tokens.count,
      let rp = context.tokens[context.consuming] as? MarkdownToken,
      rp.element == .rightParen
    else {
      context.consuming -= 4
      return nil
    }
    context.consuming += 1
    let alt = altNodes.compactMap { ($0 as? TextNode)?.content }.joined()
    return ImageNode(url: url, alt: alt)
  }

  private static func trimBackticks(_ text: String) -> String {
    var t = text
    while t.hasPrefix("`") { t.removeFirst() }
    while t.hasSuffix("`") { t.removeLast() }
    return t
  }

  private static func trimFormula(_ text: String) -> String {
    var t = text
    if t.hasPrefix("$") { t.removeFirst() }
    if t.hasSuffix("$") { t.removeLast() }
    return t
  }

  private static func joinText(
    _ tokens: [any CodeToken<MarkdownTokenElement>], from: Int, to: Int
  ) -> String {
    var s = ""
    var i = from
    while i < to {
      if let t = tokens[i] as? MarkdownToken {
        s += t.text
      }
      i += 1
    }
    return s
  }

  private static func trimAutolink(_ text: String) -> String {
    if text.hasPrefix("<") && text.hasSuffix(">") {
      return String(text.dropFirst().dropLast())
    }
    return text
  }
}

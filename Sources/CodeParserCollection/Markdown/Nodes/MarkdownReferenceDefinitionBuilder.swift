import CodeParserCore
import Foundation

/// Parses reference link definitions like `[label]: destination "title"`.
public class MarkdownReferenceDefinitionBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    // Reference definitions can appear inside container blocks but must start at
    // the beginning of a line and may not interrupt an open paragraph.
    guard context.current is DocumentNode
      || context.current is BlockquoteNode
      || context.current is ListItemNode
    else { return false }

    let tokens = context.tokens
    var idx = context.consuming
    guard idx < tokens.count else { return false }

    // Must start on a new line.
    if idx > 0 && tokens[idx - 1].element != .newline { return false }
    // Cannot interrupt a paragraph without a blank line.
    if let last = context.current.children.last,
       last is ParagraphNode,
       let state = context.state as? MarkdownConstructState,
       !state.previousLineBlank {
      return false
    }

    // Up to three leading spaces allowed.
    var indent = 0
    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == .space { indent += 1; idx += 1 }
      else if t.element == .tab { indent += 4; idx += 1 }
      else { break }
    }
    if indent > 3 { return false }

    // Opening '['
    guard idx < tokens.count, tokens[idx].element == .leftBracket else { return false }
    idx += 1

    // Label
    var labelTokens: [any CodeToken<MarkdownTokenElement>] = []
    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == .rightBracket { break }
      if t.element == .newline { return false }
      labelTokens.append(t)
      idx += 1
    }
    guard idx < tokens.count, tokens[idx].element == .rightBracket else { return false }
    idx += 1

    // Colon
    guard idx < tokens.count, tokens[idx].element == .colon else { return false }
    idx += 1

    // Spaces/tabs after colon
    var hadWhitespace = false
    while idx < tokens.count,
      (tokens[idx].element == .space || tokens[idx].element == .tab)
    {
      hadWhitespace = true
      idx += 1
    }

    if idx < tokens.count, tokens[idx].element == .newline {
      idx += 1
      var cont = 0
      while idx < tokens.count,
        (tokens[idx].element == .space || tokens[idx].element == .tab)
      {
        cont += tokens[idx].element == .tab ? 4 : 1
        idx += 1
      }
      if cont > 3 { return false }
    } else if !hadWhitespace {
      // Need at least one space or newline after colon
      return false
    }

    // Destination
    var destTokens: [any CodeToken<MarkdownTokenElement>] = []
    if idx < tokens.count, tokens[idx].element == .lt {
      idx += 1
      while idx < tokens.count {
        let t = tokens[idx]
        if t.element == .gt { idx += 1; break }
        if t.element == .newline { return false }
        destTokens.append(t)
        idx += 1
      }
    } else {
      var paren = 0
      var started = false
      while idx < tokens.count {
        let t = tokens[idx]
        if t.element == .space || t.element == .tab || t.element == .newline { break }
        started = true
        if t.element == .leftParen { paren += 1 }
        if t.element == .rightParen {
          if paren == 0 { break }
          paren -= 1
        }
        destTokens.append(t)
        idx += 1
      }
      if !started { return false }
    }

    // Skip spaces/tabs after destination
    while idx < tokens.count,
      (tokens[idx].element == .space || tokens[idx].element == .tab)
    { idx += 1 }

    var titleTokens: [any CodeToken<MarkdownTokenElement>] = []
    var endIdx = idx

    func parseTitle(start: Int) -> (Int, [any CodeToken<MarkdownTokenElement>])? {
      let opener = tokens[start].element
      let closer: MarkdownTokenElement
      switch opener {
      case .quote: closer = .quote
      case .singleQuote: closer = .singleQuote
      case .leftParen: closer = .rightParen
      default: return nil
      }
      var i = start + 1
      var res: [any CodeToken<MarkdownTokenElement>] = []
      var depth = 0
      while i < tokens.count {
        let t = tokens[i]
        if t.element == closer && depth == 0 {
          if let prev = res.last, prev.element == .backslash {
            res.append(t); i += 1; continue
          }
          i += 1
          return (i, res)
        }
        if opener == .leftParen {
          if t.element == .leftParen { depth += 1 }
          if t.element == .rightParen { depth -= 1 }
        }
        if t.element == .newline {
          if i + 1 < tokens.count && tokens[i + 1].element == .newline { return nil }
        }
        res.append(t)
        i += 1
      }
      return nil
    }

    if idx < tokens.count {
      if tokens[idx].element == .newline {
        let nl = idx
        idx += 1
        while idx < tokens.count,
          (tokens[idx].element == .space || tokens[idx].element == .tab)
        { idx += 1 }
        if idx < tokens.count,
           (tokens[idx].element == .quote || tokens[idx].element == .singleQuote || tokens[idx].element == .leftParen),
           let (nidx, tks) = parseTitle(start: idx)
        {
          titleTokens = tks
          idx = nidx
          while idx < tokens.count,
            (tokens[idx].element == .space || tokens[idx].element == .tab)
          { idx += 1 }
          guard idx < tokens.count, tokens[idx].element == .newline else { return false }
          endIdx = idx
        } else {
          // No title; definition ends at first newline
          endIdx = nl
          idx = nl
        }
      } else if tokens[idx].element == .quote
        || tokens[idx].element == .singleQuote
        || tokens[idx].element == .leftParen,
        let (nidx, tks) = parseTitle(start: idx)
      {
        titleTokens = tks
        idx = nidx
        while idx < tokens.count,
          (tokens[idx].element == .space || tokens[idx].element == .tab)
        { idx += 1 }
        guard idx < tokens.count, tokens[idx].element == .newline else { return false }
        endIdx = idx
      } else {
        guard idx < tokens.count, tokens[idx].element == .newline else { return false }
        endIdx = idx
      }
    } else {
      return false
    }

    guard endIdx < tokens.count, tokens[endIdx].element == .newline else { return false }

    idx = endIdx + 1

    var label = MarkdownInlineParser.decodeText(labelTokens)
    label = label.replacingOccurrences(of: "*", with: "")
    label = label.replacingOccurrences(of: "_", with: "")

    var dest = MarkdownInlineParser.decodeText(destTokens)
    if let encoded = dest.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) {
      dest = encoded
    }
    let title = MarkdownInlineParser.decodeText(titleTokens)

    let ref = ReferenceNode(identifier: label, url: dest, title: title)
    context.current.append(ref)
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState {
      state.previousLineBlank = true
    }
    return true
  }
}


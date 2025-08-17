import CodeParserCore
import Foundation

/// Build inline raw HTML constructs beginning with '<' (tags, comments, PI, declaration, CDATA).
struct MarkdownInlineHTMLBuilder: CodeNodeBuilder {
  typealias Node = MarkdownNodeElement
  typealias Token = MarkdownTokenElement

  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    let start = context.consuming
    guard start < tokens.count, tokens[start].element == .punctuation, tokens[start].text == "<" else { return false }
    let slice = tokens[start..<tokens.count]
    let (node, next) = build(slice, from: slice.startIndex)
    guard let n = node else { return false }
    context.current.append(n)
    context.consuming = start + slice.distance(from: slice.startIndex, to: next)
    return true
  }

  // Core logic operating on a slice, reused by dispatch
  func build(
    _ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    from start: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index
  ) -> (node: MarkdownNodeBase?, next: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index) {
    guard start < tokens.endIndex, tokens[start].element == .punctuation, tokens[start].text == "<" else {
      return (nil, start)
    }

    // Peek next token
    let next = tokens.index(after: start)
    guard next < tokens.endIndex else { return (nil, start) }
    let nt = tokens[next]

    // 1) Comment: <!-- ... -->
    if nt.element == .punctuation, nt.text == "!" {
      let afterBang = tokens.index(after: next)
      if afterBang < tokens.endIndex,
         tokens[afterBang].element == .punctuation, tokens[afterBang].text == "-",
         tokens[tokens.index(after: afterBang)].element == .punctuation, tokens[tokens.index(after: afterBang)].text == "-" {
        // consume until '-->'
        var i = tokens.index(after: tokens.index(after: afterBang))
        while i < tokens.endIndex {
          if i < tokens.endIndex, tokens[i].element == .punctuation, tokens[i].text == "-" {
            let i1 = tokens.index(after: i)
            if i1 < tokens.endIndex, tokens[i1].element == .punctuation, tokens[i1].text == "-" {
              let i2 = tokens.index(after: i1)
              if i2 < tokens.endIndex, tokens[i2].element == .punctuation, tokens[i2].text == ">" {
                // Found '-->'
                let content = tokensToString(tokens[start...i2])
                return (HTMLNode(content: content), tokens.index(after: i2))
              }
            }
          }
          i = tokens.index(after: i)
        }
        return (nil, start)
      }

      // 2) CDATA: <![CDATA[ ... ]]>
      if afterBang < tokens.endIndex,
         tokens[afterBang].element == .punctuation, tokens[afterBang].text == "[" {
        // Expect 'CDATA[' sequence next
        let seq = "CDATA["
        var i = tokens.index(after: afterBang)
        var matched = true
        for ch in seq {
          if i >= tokens.endIndex || tokens[i].text != String(ch) { matched = false; break }
          i = tokens.index(after: i)
        }
        if matched {
          // consume until ']]>'
          while i < tokens.endIndex {
            if tokens[i].element == .punctuation, tokens[i].text == "]" {
              let i1 = tokens.index(after: i)
              if i1 < tokens.endIndex, tokens[i1].element == .punctuation, tokens[i1].text == "]" {
                let i2 = tokens.index(after: i1)
                if i2 < tokens.endIndex, tokens[i2].element == .punctuation, tokens[i2].text == ">" {
                  let content = tokensToString(tokens[start...i2])
                  return (HTMLNode(content: content), tokens.index(after: i2))
                }
              }
            }
            i = tokens.index(after: i)
          }
          return (nil, start)
        }
      }

      // 3) Declaration: <!UPPER ...>
      if afterBang < tokens.endIndex {
        // Require next few letters to be uppercase A-Z (at least one)
        var i = afterBang
        var count = 0
        while i < tokens.endIndex, tokens[i].element == .characters, tokens[i].text.range(of: "^[A-Z]+$", options: .regularExpression) != nil {
          count += tokens[i].text.count
          i = tokens.index(after: i)
        }
        if count > 0 {
          // consume until '>'
          while i < tokens.endIndex {
            if tokens[i].element == .punctuation, tokens[i].text == ">" {
              let content = tokensToString(tokens[start...i])
              return (HTMLNode(content: content), tokens.index(after: i))
            }
            i = tokens.index(after: i)
          }
          return (nil, start)
        }
      }
    }

    // 4) Processing instruction: <? ... ?>
    if nt.element == .punctuation, nt.text == "?" {
      var i = tokens.index(after: next)
      while i < tokens.endIndex {
        if tokens[i].element == .punctuation, tokens[i].text == "?" {
          let i1 = tokens.index(after: i)
          if i1 < tokens.endIndex, tokens[i1].element == .punctuation, tokens[i1].text == ">" {
            let content = tokensToString(tokens[start...i1])
            return (HTMLNode(content: content), tokens.index(after: i1))
          }
        }
        i = tokens.index(after: i)
      }
      return (nil, start)
    }

    // 5) Closing tag: </tagname>
    if nt.element == .punctuation, nt.text == "/" {
      var i = tokens.index(after: next)
      var dq = 0, sq = 0
      while i < tokens.endIndex {
        let tk = tokens[i]
        if tk.element == .punctuation {
          if tk.text == "\"" { dq ^= 1 }
          else if tk.text == "'" { sq ^= 1 }
          else if tk.text == ">" && dq == 0 && sq == 0 {
            let content = tokensToString(tokens[start...i])
            if matchesAnyHTMLTag(content) {
              return (HTMLNode(content: content), tokens.index(after: i))
            } else {
              return (nil, start)
            }
          }
        }
        i = tokens.index(after: i)
      }
      return (nil, start)
    }

    // 6) Opening/self-closing tag: <tag ...> or <tag .../>
    if nt.element == .characters {
      // Scan to the matching '>' not inside quotes
      var i = next
      var dq = 0, sq = 0
      while i < tokens.endIndex {
        let tk = tokens[i]
        if tk.element == .punctuation {
          if tk.text == "\"" { dq ^= 1 }
          else if tk.text == "'" { sq ^= 1 }
          else if tk.text == ">" && dq == 0 && sq == 0 {
            // Candidate string content
            let content = tokensToString(tokens[start...i])
            if matchesAnyHTMLTag(content) {
              return (HTMLNode(content: content), tokens.index(after: i))
            } else {
              return (nil, start)
            }
          }
        }
        i = tokens.index(after: i)
      }
      return (nil, start)
    }

    return (nil, start)
  }

  // MARK: - Regex validation (CommonMark-style simplified)
  private func matchesAnyHTMLTag(_ s: String) -> Bool {
    // Patterns adapted from CommonMark spec for inline raw HTML
    let closeTag = #"^</[A-Za-z][A-Za-z0-9\-]*\s*>$"#
    let openOrSelf = #"^<[A-Za-z][A-Za-z0-9\-]*(?:\s+[A-Za-z_:][A-Za-z0-9:._\-]*(?:\s*=\s*(?:\"[^\"\n]*\"|'[^'\n]*'|[^\"'=<>`\x00-\x20]+))?)*\s*/?>$"#
    // Also allow custom elements with dash (already covered by tag regex)
    return s.range(of: closeTag, options: .regularExpression) != nil ||
           s.range(of: openOrSelf, options: .regularExpression) != nil
  }
}

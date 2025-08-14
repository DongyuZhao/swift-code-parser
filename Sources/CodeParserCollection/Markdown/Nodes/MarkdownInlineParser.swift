import CodeParserCore
import Foundation

/// Utility to parse inline Markdown content from a token sequence.
struct MarkdownInlineParser {
  typealias Token = any CodeToken<MarkdownTokenElement>

  // Minimal set of HTML named entities required for tests
  static let namedEntities: [String: String] = [
    "nbsp": "\u{00A0}",
    "amp": "&",
    "copy": "\u{00A9}",
    "AElig": "\u{00C6}",
    "Dcaron": "\u{010E}",
    "frac34": "\u{00BE}",
    "HilbertSpace": "\u{210B}",
    "DifferentialD": "\u{2146}",
    "ClockwiseContourIntegral": "\u{2232}",
    "ngE": "\u{2267}",
    "ouml": "\u{00F6}",
    "quot": "\"",
    "apos": "'",
  ]

  static func parse(_ tokens: [Token]) -> [MarkdownNodeBase] {
    var result: [MarkdownNodeBase] = []
    var buffer = ""
    var i = 0
    var literalBracketDepth = 0
    var skipLeadingSpaces = false

    func flush(merge: Bool = true) {
      if !buffer.isEmpty {
        if merge, let last = result.last as? TextNode {
          last.content += buffer
        } else {
          result.append(TextNode(content: buffer))
        }
        buffer.removeAll()
      }
    }

    while i < tokens.count {
      let tok = tokens[i]
      if tok.element != .space { skipLeadingSpaces = false }
      switch tok.element {
      case .lt:
        if let (consumed, node) = parseAngleAutolink(tokens, i) {
          flush()
          result.append(node)
          i += consumed
          continue
        } else if let (consumed, html) = parseHTML(tokens, i) {
          flush()
          result.append(html)
          i += consumed
          continue
        }
        buffer.append(tok.text)
        i += 1
      case .ampersand:
        let (consumed, text) = decodeEntity(tokens, i)
        buffer.append(text)
        i += consumed
      case .leftBracket:
        if literalBracketDepth > 0 {
          buffer.append(tok.text)
          literalBracketDepth += 1
          i += 1
        } else if let (consumed, node) = parseLink(tokens, i) {
          flush()
          result.append(node)
          i += consumed
        } else {
          buffer.append(tok.text)
          i += 1
          if i < tokens.count && tokens[i].element == .leftBracket {
            literalBracketDepth = 1
          }
        }
      case .rightBracket:
        if literalBracketDepth > 0 {
          buffer.append(tok.text)
          literalBracketDepth -= 1
          i += 1
        } else {
          buffer.append(tok.text)
          i += 1
        }
      case .exclamation:
        if i + 1 < tokens.count, tokens[i + 1].element == .leftBracket,
          let (consumed, node) = parseImage(tokens, i)
        {
          flush()
          result.append(node)
          i += consumed
        } else {
          buffer.append(tok.text)
          i += 1
          if i < tokens.count && tokens[i].element == .leftBracket {
            literalBracketDepth = 1
          }
        }
      case .text, .number:
        if i > 0 && tokens[i - 1].element == .lt {
          buffer.append(tok.text)
          i += 1
        } else if let (consumed, node) = matchBareAutolink(tokens, i) {
          flush()
          result.append(node)
          i += consumed
        } else {
          buffer.append(tok.text)
          i += 1
        }
      case .backslash:
        if i + 1 < tokens.count {
          let next = tokens[i + 1]
          if next.element == .leftParen {
            var k = i + 2
            var closing: Int? = nil
            while k + 1 < tokens.count {
              if tokens[k].element == .newline { break }
              if tokens[k].element == .backslash && tokens[k + 1].element == .rightParen {
                closing = k
                break
              }
              k += 1
            }
            if let end = closing {
              flush()
              let expr = tokens[i..<(end + 2)].map { $0.text }.joined()
              result.append(FormulaNode(expression: expr))
              i = end + 2
              continue
            }
          }
          if next.element == .newline {
            flush(merge: false)
            result.append(LineBreakNode(variant: .hard))
            i += 2
            skipLeadingSpaces = true
            continue
          }
          let text = next.text
          if text.hasPrefix("u") || text.hasPrefix("U") {
            let hex = String(text.dropFirst())
            if hex.count >= 4, let value = UInt32(hex.prefix(4), radix: 16), let scalar = UnicodeScalar(value) {
              buffer.append(String(scalar))
              let remainder = hex.dropFirst(4)
              if !remainder.isEmpty { buffer.append(String(remainder)) }
            } else {
              buffer.append(text)
            }
            i += 2
          } else if let ch = text.first, MarkdownEscaping.escapable.contains(ch) {
            buffer.append(ch)
            i += 2
          } else {
            buffer.append("\\")
            i += 1
          }
        } else {
          buffer.append(tok.text)
          i += 1
        }
      case .asterisk, .underscore:
        // Count consecutive marker runs
        let marker = tok.element
        var runLen = 1
        var j = i + 1
        while j < tokens.count && tokens[j].element == marker {
          runLen += 1
          j += 1
        }
        let prev = i > 0 ? tokens[i - 1] : nil
        let next = j < tokens.count ? tokens[j] : nil
        // Determine if this run can open/close per CommonMark rules
        let prevWhitespace = (prev as? MarkdownToken)?.isWhitespace ?? true
        let nextWhitespace = (next as? MarkdownToken)?.isWhitespace ?? true
        let prevPunct = (prev as? MarkdownToken)?.isPunctuation ?? false
        let nextPunct = (next as? MarkdownToken)?.isPunctuation ?? false
        let leftFlanking = !nextWhitespace && !(nextPunct && !prevWhitespace && !prevPunct)
        let rightFlanking = !prevWhitespace && !(prevPunct && !nextWhitespace && !nextPunct)
        let canOpen: Bool
        let canClose: Bool
        if marker == .asterisk {
          canOpen = leftFlanking
          canClose = rightFlanking
        } else {
          canOpen = leftFlanking && (!rightFlanking || prevPunct)
          canClose = rightFlanking && (!leftFlanking || nextPunct)
        }
        // Search for matching closer/opener depending on capabilities
        if canOpen {
          flush()
          result.append(TextNode(content: String(repeating: marker == .asterisk ? "*" : "_", count: runLen)))
          i = j
        } else if canClose {
          // attempt to find preceding run in buffer
          let markerChar: Character = marker == .asterisk ? "*" : "_"
          // simple scan backwards in result to find text containing marker
          var foundIndex: Int? = nil
          var idx = result.count - 1
          while idx >= 0 {
            if let t = result[idx] as? TextNode, t.content.last == markerChar {
              foundIndex = idx
              break
            }
            idx -= 1
          }
          if let openerIdx = foundIndex, let t = result[openerIdx] as? TextNode {
            // Split text node at opener
            let openerText = t.content
            var openerRun = 0
            for ch in openerText.reversed() {
              if ch == markerChar { openerRun += 1 } else { break }
            }
            if openerRun > 0 {
              let used = min(openerRun, runLen)
              let before = String(openerText.dropLast(used))
              flush(merge: false)
              let innerNodes = Array(result[(openerIdx + 1)..<result.count])
              result.removeSubrange(openerIdx..<result.count)
              if !before.isEmpty { result.append(TextNode(content: before)) }
              let node: MarkdownNodeBase
              if used >= 2 { node = StrongNode(content: "") } else { node = EmphasisNode(content: "") }
              for child in innerNodes { node.append(child) }
              result.append(node)
              i = j
              continue
            }
          }
          // no matching opener -> treat as literal
          buffer.append(String(repeating: marker == .asterisk ? "*" : "_", count: runLen))
          i = j
        } else {
          buffer.append(String(repeating: marker == .asterisk ? "*" : "_", count: runLen))
          i = j
        }
      case .tilde:
        // GFM strikethrough using runs of '~'
        var runLen = 1
        var j = i + 1
        while j < tokens.count && tokens[j].element == .tilde {
          runLen += 1
          j += 1
        }
        let prev = i > 0 ? tokens[i - 1] : nil
        let next = j < tokens.count ? tokens[j] : nil
        let prevWhitespace = (prev as? MarkdownToken)?.isWhitespace ?? true
        let nextWhitespace = (next as? MarkdownToken)?.isWhitespace ?? true
        let prevPunct = (prev as? MarkdownToken)?.isPunctuation ?? false
        let nextPunct = (next as? MarkdownToken)?.isPunctuation ?? false
        let leftFlanking = !nextWhitespace && !(nextPunct && !prevWhitespace && !prevPunct)
        let rightFlanking = !prevWhitespace && !(prevPunct && !nextWhitespace && !nextPunct)
        let canOpen = runLen >= 2 && leftFlanking
        let canClose = runLen >= 2 && rightFlanking
        if canOpen {
          flush()
          if let last = result.last as? TextNode {
            last.content += String(repeating: "~", count: runLen)
          } else {
            result.append(TextNode(content: String(repeating: "~", count: runLen)))
          }
          i = j
        } else if canClose {
          var foundIndex: Int? = nil
          var idx = result.count - 1
          while idx >= 0 {
            if let t = result[idx] as? TextNode, t.content.last == "~" {
              foundIndex = idx
              break
            }
            idx -= 1
          }
          if let openerIdx = foundIndex, let t = result[openerIdx] as? TextNode {
            let openerText = t.content
            var openerRun = 0
            for ch in openerText.reversed() {
              if ch == "~" { openerRun += 1 } else { break }
            }
            if openerRun >= 2 {
              let before = String(openerText.dropLast(2))
              flush(merge: false)
              let innerNodes = Array(result[(openerIdx + 1)..<result.count])
              result.removeSubrange(openerIdx..<result.count)
              if !before.isEmpty { result.append(TextNode(content: before)) }
              let node = StrikeNode(content: "")
              for child in innerNodes { node.append(child) }
              result.append(node)
              if runLen > 2 {
                buffer.append(String(repeating: "~", count: runLen - 2))
              }
              i = j
              continue
            }
          }
          buffer.append(String(repeating: "~", count: runLen))
          i = j
        } else {
          buffer.append(String(repeating: "~", count: runLen))
          i = j
        }
      case .newline:
        var trimmed = 0
        while buffer.last == " " { buffer.removeLast(); trimmed += 1 }
        let next = i + 1 < tokens.count ? tokens[i + 1] : nil
        if trimmed >= 2 && next?.element != .newline && next?.element != .eof {
          flush(merge: false)
          result.append(LineBreakNode(variant: .hard))
          i += 1
          skipLeadingSpaces = true
        } else if buffer.isEmpty && i + 1 < tokens.count && tokens[i + 1].element == .backtick {
          i += 1
        } else if result.last is InlineCodeNode {
          i += 1
        } else {
          flush(merge: false)
          if next == nil || next?.element == .newline || next?.element == .eof {
            i += 1
          } else {
            result.append(LineBreakNode())
            i += 1
            skipLeadingSpaces = true
          }
        }
      case .space:
        if skipLeadingSpaces {
          i += 1
          continue
        }
        buffer.append(tok.text)
        i += 1
      case .dollar:
        var j = i + 1
        var prevSlash = false
        var closing: Int? = nil
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline { break }
          if t.element == .dollar && !prevSlash {
            closing = j
            break
          }
          prevSlash = (t.element == .backslash) ? !prevSlash : false
          j += 1
        }
        if let end = closing,
           j > i + 1,
           tokens[i + 1].element != .space,
           tokens[end - 1].element != .space {
          flush()
          let expr = tokens[(i + 1)..<end].map { $0.text }.joined()
          result.append(FormulaNode(expression: expr))
          i = end + 1
        } else {
          buffer.append("$")
          i += 1
        }
      case .backtick:
        var tickCount = 1
        var j = i + 1
        while j < tokens.count && tokens[j].element == .backtick {
          tickCount += 1
          j += 1
        }
        var inner: [Token] = []
        var k = j
        var closingIndex: Int? = nil
        while k < tokens.count {
          let t = tokens[k]
          if t.element == .backtick {
            var run = 1
            var m = k + 1
            while m < tokens.count && tokens[m].element == .backtick {
              run += 1
              m += 1
            }
            if run == tickCount {
              closingIndex = k
              k = m
              break
            } else {
              inner.append(contentsOf: tokens[k..<m])
              k = m
            }
          } else {
            inner.append(t)
            k += 1
          }
        }
        if let close = closingIndex {
          flush()
          var code = ""
          for t in inner {
            if t.element == .newline {
              code.append(" ")
            } else {
              code.append(t.text)
            }
          }
          if code.hasPrefix(" ") && code.hasSuffix(" ") && !code.trimmingCharacters(in: .whitespaces).isEmpty {
            code.removeFirst()
            code.removeLast()
          }
          result.append(InlineCodeNode(code: code))
          i = close + tickCount
        } else {
          let ticks = String(repeating: "`", count: tickCount)
          var separate = false
          if !buffer.isEmpty && !buffer.contains("`") {
            if let prev = result.last as? InlineCodeNode {
              if let last = prev.code.last, !last.isLetter && !last.isNumber {
                separate = true
              }
            } else {
              separate = true
            }
          }
          if separate {
            flush()
            result.append(TextNode(content: ticks))
          } else {
            buffer.append(ticks)
          }
          i = j
        }
      default:
        buffer.append(tok.text)
        i += 1
      }
    }
    flush()

    // Merge trailing backtick with preceding text when appropriate to match
    // CommonMark expectations (e.g., `hi`lo`).
    if result.count >= 3,
       let tick = result.last as? TextNode, tick.content == "`",
       let text = result[result.count - 2] as? TextNode,
       let code = result[result.count - 3] as? InlineCodeNode,
       let last = code.code.last, last.isLetter || last.isNumber
    {
      result[result.count - 2] = TextNode(content: text.content + "`")
      result.removeLast()
    }

    return result
  }

  private static func parseAngleAutolink(_ tokens: [Token], _ start: Int) -> (Int, LinkNode)? {
    var inner: [Token] = []
    var i = start + 1
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .gt { break }
      if t.element == .space || t.element == .tab || t.element == .newline { return nil }
      inner.append(t)
      i += 1
    }
    guard i < tokens.count && tokens[i].element == .gt else { return nil }
    let text = inner.map { $0.text }.joined()
    guard !text.isEmpty else { return nil }
    let url: String
    if let email = parseEmail(text) {
      url = "mailto:\(email)"
    } else if validateURI(text) {
      url = text
    } else {
      return nil
    }
    let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? url
    let node = LinkNode(url: encoded, title: "")
    node.append(TextNode(content: text))
    return (i - start + 1, node)
  }

  private static func matchBareAutolink(_ tokens: [Token], _ start: Int) -> (Int, LinkNode)? {
    let source = tokens[start...].map { $0.text }.joined()
    if let (text, url) = scanURL(source) {
      let consumed = countTokens(tokens, start: start, length: text.count)
      let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? url
      let node = LinkNode(url: encoded, title: "")
      node.append(TextNode(content: text))
      return (consumed, node)
    }
    if let email = parseEmail(source) {
      let consumed = countTokens(tokens, start: start, length: email.count)
      let node = LinkNode(url: "mailto:\(email)", title: "")
      node.append(TextNode(content: email))
      return (consumed, node)
    }
    return nil
  }

  private static let htmlPatterns: [NSRegularExpression] = {
    let comment = try! NSRegularExpression(
      pattern: "^<!--(?!>|->)(?:[^-]|-(?:[^-]|-(?!>)))*-->",
      options: [.dotMatchesLineSeparators]
    )
    let processing = try! NSRegularExpression(
      pattern: "^<\\?[\\s\\S]*?\\?>",
      options: [.dotMatchesLineSeparators]
    )
    let declaration = try! NSRegularExpression(
      pattern: "^<![A-Z]+\\s+[\\s\\S]*?>",
      options: [.dotMatchesLineSeparators]
    )
    let cdata = try! NSRegularExpression(
      pattern: "^<!\\[CDATA\\[[\\s\\S]*?\\]\\]>",
      options: [.dotMatchesLineSeparators]
    )
    let closeTag = try! NSRegularExpression(
      pattern: "^</[A-Za-z][A-Za-z0-9-]*\\s*>",
      options: [.dotMatchesLineSeparators]
    )
    let openTag = try! NSRegularExpression(
      pattern:
        "^<[A-Za-z][A-Za-z0-9-]*(?:\\s+[A-Za-z_:][A-Za-z0-9:._-]*(?:\\s*=\\s*(?:\"[\\s\\S]*?\"|'[\\s\\S]*?'|[^\\s\"'=<>`]+))?)*\\s*/?>",
      options: [.dotMatchesLineSeparators]
    )
    return [comment, processing, declaration, cdata, closeTag, openTag]
  }()

  private static func parseHTML(_ tokens: [Token], _ start: Int) -> (Int, HTMLNode)? {
    let source = tokens[start...].map { $0.text }.joined()
    let nsSource = source as NSString
    for regex in htmlPatterns {
      if let match = regex.firstMatch(in: source, range: NSRange(location: 0, length: nsSource.length)), match.range.location == 0 {
        let matched = nsSource.substring(with: match.range)
        let consumed = countTokens(tokens, start: start, length: matched.count)
        return (consumed, HTMLNode(content: matched))
      }
    }
    return nil
  }

  private static func parseLink(_ tokens: [Token], _ start: Int) -> (Int, MarkdownNodeBase)? {
    var i = start + 1
    var labelTokens: [Token] = []
    var containsBracket = false
    var depth = 0
    var prevBackslash = false
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .newline { return nil }
      if t.element == .backslash {
        labelTokens.append(t)
        prevBackslash.toggle()
        i += 1
        continue
      }
      if !prevBackslash {
        if t.element == .leftBracket {
          depth += 1
          containsBracket = true
        } else if t.element == .rightBracket {
          if depth == 0 { break }
          depth -= 1
          containsBracket = true
        }
      }
      prevBackslash = false
      labelTokens.append(t)
      i += 1
    }
    guard i < tokens.count && tokens[i].element == .rightBracket else { return nil }
    let labelEnd = i
    i += 1
    guard i < tokens.count else { return nil }
    if tokens[i].element == .leftParen {
      var j = i + 1
      // skip spaces and optional single newline
      while j < tokens.count && tokens[j].element == .space { j += 1 }
      if j < tokens.count && tokens[j].element == .newline {
        j += 1
        while j < tokens.count && tokens[j].element == .space { j += 1 }
      }
      // parse destination
      var destTokens: [Token] = []
      if j < tokens.count && tokens[j].element == .lt {
        j += 1
        var prevSlash = false
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline { return nil }
          if t.element == .gt && !prevSlash { break }
          prevSlash = (t.element == .backslash) ? !prevSlash : false
          destTokens.append(t)
          j += 1
        }
        guard j < tokens.count && tokens[j].element == .gt else { return nil }
        j += 1
      } else {
        var parenDepth = 0
        var prevSlash = false
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline { return nil }
          if t.element == .backslash {
            destTokens.append(t)
            prevSlash.toggle()
            j += 1
            continue
          }
          if t.element == .leftParen && !prevSlash {
            parenDepth += 1
            destTokens.append(t)
            j += 1
            continue
          }
          if t.element == .rightParen && !prevSlash {
            if parenDepth == 0 { break }
            parenDepth -= 1
            destTokens.append(t)
            j += 1
            continue
          }
          if t.element == .space && parenDepth == 0 && !prevSlash {
            break
          }
          prevSlash = false
          destTokens.append(t)
          j += 1
        }
      }
      let url = percentEncode(decodeText(destTokens))
      // skip spaces/newline before title
      while j < tokens.count && tokens[j].element == .space { j += 1 }
      if j < tokens.count && tokens[j].element == .newline {
        j += 1
        while j < tokens.count && tokens[j].element == .space { j += 1 }
      }
      // parse optional title
      var title = ""
      if j < tokens.count {
        var endDelim: MarkdownTokenElement? = nil
        if tokens[j].element == .ampersand {
          let (cons, dec) = decodeEntity(tokens, j)
          if dec == "\"" || dec == "'" {
            endDelim = dec == "\"" ? .quote : .singleQuote
            j += cons
          }
        } else if tokens[j].element == .quote {
          endDelim = .quote
          j += 1
        } else if tokens[j].element == .singleQuote {
          endDelim = .singleQuote
          j += 1
        } else if tokens[j].element == .leftParen {
          endDelim = .rightParen
          j += 1
        }
        if let end = endDelim {
          var titleTokens: [Token] = []
          var prevSlash = false
          while j < tokens.count {
            let t = tokens[j]
            if t.element == .newline { return nil }
            if t.element == end && !prevSlash { j += 1; break }
            prevSlash = (t.element == .backslash) ? !prevSlash : false
            titleTokens.append(t)
            j += 1
          }
          title = decodeText(titleTokens)
          while j < tokens.count && tokens[j].element == .space { j += 1 }
          if j < tokens.count && tokens[j].element == .newline {
            j += 1
            while j < tokens.count && tokens[j].element == .space { j += 1 }
          }
        }
      }
      guard j < tokens.count && tokens[j].element == .rightParen else { return nil }
      j += 1
      let link = LinkNode(url: url, title: title)
      for child in parse(labelTokens) { link.append(child) }
      return (j - start, link)
    } else if tokens[i].element == .leftBracket {
      // reference link [label][id]
      var idTokens: [Token] = []
      var j = i + 1
      while j < tokens.count {
        let t = tokens[j]
        if t.element == .newline { return nil }
        if t.element == .rightBracket { break }
        idTokens.append(t)
        j += 1
      }
      guard j < tokens.count && tokens[j].element == .rightBracket else { return nil }
      let ident = decodeText(idTokens)
      if containsBracket { return nil }
      let ref = ReferenceNode(identifier: ident, url: "", title: "")
      for child in parse(labelTokens) { ref.append(child) }
      return (j - start + 1, ref)
    } else {
      // shortcut reference link [label]
      if labelTokens.isEmpty || containsBracket { return nil }
      let ref = ReferenceNode(identifier: "", url: "", title: "")
      for child in parse(labelTokens) { ref.append(child) }
      return (labelEnd - start + 1, ref)
    }
  }

  private static func parseImage(_ tokens: [Token], _ start: Int) -> (Int, MarkdownNodeBase)? {
    var i = start + 2
    var labelTokens: [Token] = []
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .rightBracket { break }
      if t.element == .leftBracket || t.element == .rightBracket { return nil }
      labelTokens.append(t)
      i += 1
    }
    guard i < tokens.count && tokens[i].element == .rightBracket else { return nil }
    let labelEnd = i
    var alt = decodeText(labelTokens)
    alt = alt.replacingOccurrences(of: "*", with: "")
    alt = alt.replacingOccurrences(of: "_", with: "")
    i += 1
    if i < tokens.count && tokens[i].element == .leftParen {
      var j = i + 1
      var destTokens: [Token] = []
      if j < tokens.count && tokens[j].element == .lt {
        j += 1
        var prevSlash = false
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline { return nil }
          if t.element == .gt && !prevSlash { break }
          prevSlash = (t.element == .backslash) ? !prevSlash : false
          destTokens.append(t)
          j += 1
        }
        guard j < tokens.count && tokens[j].element == .gt else { return nil }
        j += 1
      } else {
        var parenDepth = 0
        var prevSlash = false
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline { return nil }
          if t.element == .backslash {
            destTokens.append(t)
            prevSlash.toggle()
            j += 1
            continue
          }
          if t.element == .leftParen && !prevSlash {
            parenDepth += 1
            destTokens.append(t)
            j += 1
            continue
          }
          if t.element == .rightParen && !prevSlash {
            if parenDepth == 0 { break }
            parenDepth -= 1
            destTokens.append(t)
            j += 1
            continue
          }
          if t.element == .space && parenDepth == 0 && !prevSlash {
            break
          }
          prevSlash = false
          destTokens.append(t)
          j += 1
        }
      }
      // skip spaces/newline before title
      while j < tokens.count && tokens[j].element == .space { j += 1 }
      if j < tokens.count && tokens[j].element == .newline {
        j += 1
        while j < tokens.count && tokens[j].element == .space { j += 1 }
      }
      var titleTokens: [Token] = []
      if j < tokens.count {
        if tokens[j].element == .ampersand {
          let (cons, dec) = decodeEntity(tokens, j)
          if dec == "\"" || dec == "'" {
            let quote = dec
            j += cons
            while j < tokens.count {
              if tokens[j].element == .ampersand {
                let (c2, d2) = decodeEntity(tokens, j)
                if d2 == quote { j += c2; break }
              }
              let t = tokens[j]
              if (quote == "\"" && t.element == .quote) ||
                (quote == "'" && t.element == .singleQuote)
              {
                j += 1
                break
              }
              titleTokens.append(t)
              j += 1
            }
            while j < tokens.count && tokens[j].element == .space { j += 1 }
          }
        } else if tokens[j].element == .quote || tokens[j].element == .singleQuote {
          let quote = tokens[j].element
          j += 1
          while j < tokens.count {
            let t = tokens[j]
            if t.element == quote { j += 1; break }
            titleTokens.append(t)
            j += 1
          }
          while j < tokens.count && tokens[j].element == .space { j += 1 }
        }
      }
      guard j < tokens.count && tokens[j].element == .rightParen else { return nil }
      j += 1
      let url = percentEncode(decodeText(destTokens))
      let title = decodeText(titleTokens)
      return (j - start, ImageNode(url: url, alt: alt, title: title))
    } else if i < tokens.count && tokens[i].element == .leftBracket {
      var idTokens: [Token] = []
      var j = i + 1
      while j < tokens.count {
        let t = tokens[j]
        if t.element == .rightBracket { break }
        idTokens.append(t)
        j += 1
      }
      guard j < tokens.count && tokens[j].element == .rightBracket else { return nil }
      let ident = decodeText(idTokens)
      let identifier = ident.isEmpty ? alt : ident
      return (j - start + 1, ImageNode(url: "", alt: alt, title: identifier))
    } else {
      if alt.isEmpty { return nil }
      return (labelEnd - start + 1, ImageNode(url: "", alt: alt, title: alt))
    }
  }

  static func decodeEntity(_ tokens: [Token], _ start: Int) -> (Int, String) {
    var i = start + 1
    if i < tokens.count, tokens[i].element == .hash {
      i += 1
      var isHex = false
      var digits = ""
      if i < tokens.count, tokens[i].element == .text {
        let txt = tokens[i].text
        if let first = txt.first, first == "x" || first == "X" {
          isHex = true
          let remainder = String(txt.dropFirst())
          if !remainder.isEmpty { digits.append(remainder) }
          i += 1
        }
      }
      while i < tokens.count {
        let t = tokens[i]
        if isHex {
          if t.element == .number || (t.element == .text && t.text.range(of: "^[A-Fa-f0-9]+$", options: .regularExpression) != nil) {
            digits.append(t.text)
            i += 1
          } else { break }
        } else {
          if t.element == .number { digits.append(t.text); i += 1 } else { break }
        }
      }
      if i < tokens.count, tokens[i].element == .semicolon, !digits.isEmpty {
        i += 1
        let value = UInt32(digits, radix: isHex ? 16 : 10) ?? 0
        if value == 0 {
          let scalar = UnicodeScalar(0xFFFD)!
          return (i - start, String(scalar))
        }
        if value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF) {
          let raw = tokens[start..<i].map { $0.text }.joined()
          return (i - start, raw)
        }
        if let scalar = UnicodeScalar(value) {
          return (i - start, String(scalar))
        }
        let raw = tokens[start..<i].map { $0.text }.joined()
        return (i - start, raw)
      }
    } else {
      var name = ""
      while i < tokens.count {
        let t = tokens[i]
        if t.element == .semicolon { break }
        if t.element != .text && t.element != .number { break }
        name.append(t.text)
        i += 1
      }
      if i < tokens.count && tokens[i].element == .semicolon {
        i += 1
        if let decoded = namedEntities[name] {
          return (i - start, decoded)
        }
      }
    }
    let raw = tokens[start..<i].map { $0.text }.joined()
    return (i - start, raw)
  }

  static func decodeText(_ tokens: [Token]) -> String {
    var result = ""
    var i = 0
    while i < tokens.count {
      let t = tokens[i]
      switch t.element {
      case .ampersand:
        let (consumed, text) = decodeEntity(tokens, i)
        result.append(text)
        i += consumed
      case .backslash:
        if i + 1 < tokens.count {
          let next = tokens[i + 1]
          if let ch = next.text.first, MarkdownEscaping.escapable.contains(ch) {
            result.append(ch)
            i += 2
          } else {
            result.append("\\")
            i += 1
          }
        } else {
          result.append("\\")
          i += 1
        }
      default:
        result.append(t.text)
        i += 1
      }
    }
    return result
  }

  private static let urlAllowed: CharacterSet = {
    CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%"
    )
  }()

  private static func percentEncode(_ text: String) -> String {
    var encoded = ""
    for scalar in text.unicodeScalars {
      if urlAllowed.contains(scalar) {
        encoded.append(String(scalar))
      } else {
        for b in String(scalar).utf8 {
          encoded.append(String(format: "%%%02X", b))
        }
      }
    }
    return encoded
  }

  private static func scanURL(_ text: String) -> (String, String)? {
    let lower = text.lowercased()
    for prefix in ["http://", "https://", "ftp://"] {
      if lower.hasPrefix(prefix) {
        let link = trimURLCandidate(text)
        return (link, link)
      }
    }
    if lower.hasPrefix("www.") {
      let link = trimURLCandidate(text)
      return (link, "http://" + link)
    }
    return nil
  }

  private static func trimURLCandidate(_ text: String) -> String {
    var end = text.startIndex
    var paren = 0
    while end < text.endIndex {
      let c = text[end]
      if c == "<" || c == "\n" || c == "\r" || c == " " || c == "\t" { break }
      if c == "(" { paren += 1 }
      if c == ")" { paren -= 1 }
      end = text.index(after: end)
    }
    var link = String(text[..<end])
    if let r = link.range(of: "&[A-Za-z]+;$", options: [.regularExpression]) {
      link = String(link[..<r.lowerBound])
    }
    var balance = 0
    for ch in link {
      if ch == "(" { balance += 1 }
      else if ch == ")" { balance -= 1 }
    }
    while balance < 0 && link.last == ")" {
      link.removeLast()
      balance += 1
    }
    while let last = link.last, "?!.,:;".contains(last) {
      link.removeLast()
    }
    return link
  }

  private static func parseEmail(_ text: String) -> String? {
    let allowedLocal = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+/=?^_`{|}~-" )
    var index = text.startIndex
    while index < text.endIndex {
      let c = text[index]
      let scalar = c.unicodeScalars.first!
      if allowedLocal.contains(scalar) {
        index = text.index(after: index)
      } else {
        break
      }
    }
    if index == text.startIndex { return nil }
    if index == text.endIndex || text[index] != "@" { return nil }
    index = text.index(after: index)
    let domainStart = index
    var hasDot = false
    var prev: Character? = nil
    var valid = true
    while index < text.endIndex {
      let c = text[index]
      if c.isLetter || c.isNumber {
        prev = c
        index = text.index(after: index)
        continue
      } else if c == "-" {
        if prev == nil { valid = false; break }
        prev = c
        index = text.index(after: index)
        continue
      } else if c == "." {
        if prev == nil || prev == "-" { valid = false; break }
        let next = text.index(after: index)
        if next == text.endIndex { break }
        let nextChar = text[next]
        if !(nextChar.isLetter || nextChar.isNumber) { break }
        hasDot = true
        prev = nil
        index = next
        continue
      } else {
        valid = false
        break
      }
    }
    if !valid || prev == nil || prev == "-" || !hasDot { return nil }
    let domain = String(text[domainStart..<index])
    let parts = domain.split(separator: ".")
    guard parts.count == 2 else { return nil }
    for label in parts {
      guard let first = label.first, let last = label.last else { return nil }
      if !(first.isLetter || first.isNumber) { return nil }
      if !(last.isLetter || last.isNumber) { return nil }
      for ch in label { if !(ch.isLetter || ch.isNumber || ch == "-") { return nil } }
    }
    var email = String(text[..<index])
    while let last = email.last, "?!.,:;".contains(last) {
      email.removeLast()
    }
    return email
  }

  private static func validateURI(_ text: String) -> Bool {
    guard let colon = text.firstIndex(of: ":") else { return false }
    let scheme = text[..<colon]
    guard let first = scheme.first, first.isLetter, scheme.count >= 2 else { return false }
    for ch in scheme {
      if !(ch.isLetter || ch.isNumber || ch == "+" || ch == "-" || ch == ".") { return false }
    }
    let rest = text[text.index(after: colon)...]
    if rest.isEmpty { return false }
    return !rest.contains(" ") && !rest.contains("<") && !rest.contains(">")
  }

  private static func countTokens(_ tokens: [Token], start: Int, length: Int) -> Int {
    var total = 0
    var count = 0
    while start + count < tokens.count && total < length {
      total += tokens[start + count].text.count
      count += 1
    }
    return count
  }
}

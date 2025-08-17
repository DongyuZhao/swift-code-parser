import CodeParserCore
import Foundation

// MARK: - Helper Functions
fileprivate func tokensToString(_ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>) -> String {
  return tokens.map { $0.text }.joined()
}

fileprivate func parseInline(_ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>) -> [MarkdownNodeBase] {
  var nodes: [MarkdownNodeBase] = []
  var buffer = ""
  var i = tokens.startIndex
  while i < tokens.endIndex {
    let t = tokens[i]
    if t.element == .punctuation, t.text == "*" {
      var j = tokens.index(after: i)
      var inner: [any CodeToken<MarkdownTokenElement>] = []
      var found = false
      while j < tokens.endIndex {
        let nt = tokens[j]
        if nt.element == .punctuation, nt.text == "*" {
          found = true
          break
        }
        inner.append(nt)
        j = tokens.index(after: j)
      }
      if found {
        if !buffer.isEmpty {
          nodes.append(TextNode(content: buffer))
          buffer.removeAll()
        }
        let em = EmphasisNode(content: "")
        let innerText = tokensToString(inner[inner.startIndex..<inner.endIndex])
        em.append(TextNode(content: innerText))
        nodes.append(em)
        i = tokens.index(after: j)
        continue
      }
    }
    buffer.append(t.text)
    i = tokens.index(after: i)
  }
  if !buffer.isEmpty {
    nodes.append(TextNode(content: buffer))
  }
  return nodes
}

fileprivate func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> (Bool, Int) {
  var idx = start
  var onlySpaces = true
  while idx < tokens.count {
    let t = tokens[idx]
    if t.element == .newline || t.element == .eof { return (onlySpaces, idx + 1) }
    if t.element != .whitespaces { onlySpaces = false }
    idx += 1
  }
  return (onlySpaces, idx)
}

fileprivate func isATXHeadingStart(_ tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> Bool {
  var idx = start
  var spaceCount = 0
  while idx < tokens.count, tokens[idx].element == .whitespaces {
    spaceCount += tokens[idx].text.count
    if spaceCount > 3 { return false }
    idx += 1
  }
  var hashCount = 0
  while idx < tokens.count, tokens[idx].element == .punctuation,
    tokens[idx].text == "#" {
    hashCount += 1
    idx += 1
  }
  if hashCount == 0 || hashCount > 6 { return false }
  if idx >= tokens.count { return false }
  let next = tokens[idx]
  if next.element == .whitespaces || next.element == .newline || next.element == .eof {
    return true
  }
  return false
}

// MARK: - Thematic Break Builder
public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .whitespaces {
      spaces += tokens[idx].text.count
      if spaces > 3 { return false }
      idx += 1
    }
    var stars = 0
    var scan = idx
    while scan < tokens.count {
      let t = tokens[scan]
      if t.element == .newline || t.element == .eof { break }
      if t.element == .punctuation, t.text == "*" {
        stars += 1
      } else if t.element == .whitespaces {
        // ok
      } else {
        return false
      }
      scan += 1
    }
    if stars >= 3 {
      let node = ThematicBreakNode()
      context.current.append(node)
      if scan < tokens.count, tokens[scan].element == .newline { scan += 1 }
      context.consuming = scan
      return true
    }
    return false
  }
}

// MARK: - Code Block Builder (indented)
public class MarkdownCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .whitespaces, spaces < 4 {
      spaces += tokens[idx].text.count
      idx += 1
    }
    if spaces < 4 { return false }
    // capture until newline
    var lineTokens: [any CodeToken<Token>] = []
    var scan = idx
    while scan < tokens.count {
      let t = tokens[scan]
      if t.element == .newline || t.element == .eof { break }
      lineTokens.append(t)
      scan += 1
    }
    let text = tokensToString(lineTokens[lineTokens.startIndex..<lineTokens.endIndex])
    let node = CodeBlockNode(source: text)
    context.current.append(node)
    if scan < tokens.count, tokens[scan].element == .newline { scan += 1 }
    context.consuming = scan
    return true
  }
}

// MARK: - ATX Heading Builder
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    let startIdx = idx
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .whitespaces {
      spaces += tokens[idx].text.count
      if spaces > 3 { return false }
      idx += 1
    }
    var hashes = 0
    while idx < tokens.count, tokens[idx].element == .punctuation, tokens[idx].text == "#" {
      hashes += 1
      idx += 1
    }
    if hashes == 0 || hashes > 6 { return false }
    if idx >= tokens.count { return false }
    let next = tokens[idx]
    if next.element != .whitespaces && next.element != .newline && next.element != .eof {
      return false
    }
    let hasLeadingSpace = next.element == .whitespaces
    if hasLeadingSpace { idx += 1 }
    let contentStart = idx
    while idx < tokens.count, tokens[idx].element != .newline, tokens[idx].element != .eof {
      idx += 1
    }
    var end = idx
    // trim trailing spaces
    while end > contentStart && tokens[end - 1].element == .whitespaces {
      end -= 1
    }
    // handle closing sequence
    var closing = end
    var hashCount = 0
    while closing > contentStart {
      let t = tokens[closing - 1]
      if t.element == .punctuation, t.text == "#" {
        hashCount += 1
        closing -= 1
      } else { break }
    }
    if hashCount > 0 {
      if closing > contentStart,
        tokens[closing - 1].element == .whitespaces {
        end = closing - 1
      } else if closing == contentStart && hasLeadingSpace {
        end = contentStart
      }
    }
    let inlineTokens = tokens[contentStart..<end]
    let children = parseInline(inlineTokens)
    let node = HeaderNode(level: hashes)
    for c in children { node.append(c) }
    context.current.append(node)
    if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }
    context.consuming = idx
    return true
  }
}

// MARK: - Paragraph Builder (very simple)
public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    // Blank line handling
    let (blank, nextIdx) = isBlankLine(tokens, start: idx)
    if blank {
      context.consuming = nextIdx
      return true
    }
    var lines: [String] = []
    while true {
      var lineEnd = idx
      while lineEnd < tokens.count, tokens[lineEnd].element != .newline,
        tokens[lineEnd].element != .eof {
        lineEnd += 1
      }
      var line = tokensToString(tokens[idx..<lineEnd])
      if !lines.isEmpty, line.hasPrefix("    ") {
        line.removeFirst(4)
      }
      lines.append(line)
      idx = lineEnd
      if idx < tokens.count, tokens[idx].element == .newline { idx += 1 } else { break }
      if idx >= tokens.count { break }
      let (isBlank, _) = isBlankLine(tokens, start: idx)
      if isBlank { break }
      if isATXHeadingStart(tokens, start: idx) { break }
      // thematic break check
      var tmp = context
      tmp.consuming = idx
      let th = MarkdownThematicBreakBuilder()
      if th.build(from: &tmp) { break }
    }
    let p = ParagraphNode(range: tokens[context.consuming].range)
    for (i, line) in lines.enumerated() {
      p.append(TextNode(content: line))
      if i < lines.count - 1 { p.append(LineBreakNode()) }
    }
    context.current.append(p)
    context.consuming = idx
    return true
  }
}


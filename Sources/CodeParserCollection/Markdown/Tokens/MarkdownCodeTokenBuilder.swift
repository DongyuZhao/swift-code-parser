import CodeParserCore
import Foundation

public class MarkdownCodeTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
    guard context.consuming < context.source.endIndex else { return false }
    let start = context.consuming
    let char = context.source[start]

    if char == "`" {
      if let fenced = buildFencedCode(from: &context, start: start, fenceChar: char) {
        context.tokens.append(fenced)
        return true
      }
      if let inline = buildInlineCode(from: &context, start: start) {
        context.tokens.append(inline)
        return true
      }
      // fallthrough: let single char builder / text builder handle stray backtick
      return false
    } else if char == "~" {
      // Only treat as fenced code if run >=3; otherwise let single char builder capture tildes
      var count = 0
      var idx = start
      while idx < context.source.endIndex && context.source[idx] == "~" {
        count += 1
        idx = context.source.index(after: idx)
      }
      if count >= 3 { // fenced code
        if let fenced = buildFencedCode(from: &context, start: start, fenceChar: "~") {
          context.tokens.append(fenced)
          return true
        }
      }
      return false
    }

    if (char == " " || char == "\t") && isLineStart(source: context.source, index: start) {
      if let token = buildIndentedCode(from: &context, start: start) {
        context.tokens.append(token)
        return true
      }
    }

    return false
  }

  private func isLineStart(source: String, index: String.Index) -> Bool {
    if index == source.startIndex { return true }
    let prev = source.index(before: index)
    let c = source[prev]
    return c == "\n" || c == "\r"
  }

  private func buildFencedCode(
    from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index, fenceChar: Character
  ) -> MarkdownToken? {
    var tickCount = 0
    var idx = start
    while idx < context.source.endIndex && context.source[idx] == fenceChar {
      tickCount += 1
      idx = context.source.index(after: idx)
    }
    if tickCount < 3 { return nil }

    // skip language specifier until newline
    while idx < context.source.endIndex && context.source[idx] != "\n"
      && context.source[idx] != "\r"
    {
      idx = context.source.index(after: idx)
    }

    // skip newline
    if idx < context.source.endIndex {
      if context.source[idx] == "\r" {
        let next = context.source.index(after: idx)
        if next < context.source.endIndex && context.source[next] == "\n" {
          idx = context.source.index(after: next)
        } else {
          idx = next
        }
      } else if context.source[idx] == "\n" {
        idx = context.source.index(after: idx)
      }
    }

    var search = idx
    var closingStart: String.Index? = nil
    while search < context.source.endIndex {
      if context.source[search] == fenceChar {
        let fenceStart = search
        var count = 0
        while search < context.source.endIndex && context.source[search] == fenceChar {
          count += 1
          search = context.source.index(after: search)
        }
        if count >= tickCount {
          closingStart = fenceStart
          break
        }
      } else {
        search = context.source.index(after: search)
      }
    }

    let end: String.Index
    if closingStart != nil {
      end = search
      context.consuming = search
    } else {
      end = context.source.endIndex
      context.consuming = context.source.endIndex
    }

    let range = start..<end
  let text = String(context.source[range])
    return MarkdownToken.fencedCodeBlock(text, at: range)
  }

  private func buildInlineCode(
    from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index
  ) -> MarkdownToken? {
    // Determine opening run length
    var openingLen = 0
    var i = start
    while i < context.source.endIndex && context.source[i] == "`" {
      openingLen += 1
      i = context.source.index(after: i)
    }
    if openingLen == 0 { return nil }
    let contentStart = i
    // Search for matching closing run
    var search = contentStart
    var closingStart: String.Index? = nil
    while search < context.source.endIndex {
      if context.source[search] == "`" {
        var run = 0
        var runIdx = search
        while runIdx < context.source.endIndex && context.source[runIdx] == "`" {
          run += 1
          runIdx = context.source.index(after: runIdx)
        }
        if run == openingLen { closingStart = search; break }
        search = runIdx
      } else {
        search = context.source.index(after: search)
      }
    }
    guard let close = closingStart else { return nil }
    let end = context.source.index(close, offsetBy: openingLen)
    let range = start..<end
    context.consuming = end
    let text = String(context.source[range])
    return MarkdownToken.inlineCode(text, at: range)
  }

  private func buildIndentedCode(
    from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index
  ) -> MarkdownToken? {
    var idx = start
    var spaceCount = 0
    while idx < context.source.endIndex {
      if context.source[idx] == " " {
        spaceCount += 1
        if spaceCount >= 4 {
          idx = context.source.index(after: idx)
          break
        }
      } else if context.source[idx] == "\t" {
        spaceCount = 4
        idx = context.source.index(after: idx)
        break
      } else {
        break
      }
      idx = context.source.index(after: idx)
    }
    if spaceCount < 4 { return nil }

    var hasContent = false
    var check = idx
    while check < context.source.endIndex && context.source[check] != "\n"
      && context.source[check] != "\r"
    {
      if context.source[check] != " " && context.source[check] != "\t" {
        hasContent = true
        break
      }
      check = context.source.index(after: check)
    }
    if !hasContent { return nil }

    let blockStart = start
    var blockEnd = start
    var scan = idx
    while scan < context.source.endIndex {
      while scan < context.source.endIndex && context.source[scan] != "\n"
        && context.source[scan] != "\r"
      {
        scan = context.source.index(after: scan)
      }
      blockEnd = scan
      if scan < context.source.endIndex {
        if context.source[scan] == "\r" {
          scan = context.source.index(after: scan)
          if scan < context.source.endIndex && context.source[scan] == "\n" {
            scan = context.source.index(after: scan)
          }
        } else if context.source[scan] == "\n" {
          scan = context.source.index(after: scan)
        }
      }
      let lineStart = scan
      var indent = 0
      var blank = true
      while scan < context.source.endIndex && context.source[scan] != "\n"
        && context.source[scan] != "\r"
      {
        if context.source[scan] == " " {
          indent += 1
        } else if context.source[scan] == "\t" {
          indent = 4
          blank = false
          break
        } else {
          blank = false
          break
        }
        scan = context.source.index(after: scan)
      }
      if blank { continue }
      if indent < 4 { break }
      scan = lineStart
    }

    let range = blockStart..<blockEnd
    let text = String(context.source[range])
    context.consuming = blockEnd
    return MarkdownToken.indentedCodeBlock(text, at: range)
  }
}

import CodeParserCore
import Foundation

// MARK: - Block-level Utilities
func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> (Bool, Int) {
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

func isATXHeadingStart(_ tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> Bool {
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

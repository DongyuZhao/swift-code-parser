import CodeParserCore
import Foundation

package enum MarkdownBlockquoteUtils {
  /// Returns the token index immediately after a valid blockquote marker ('>' with optional space)
  /// if present at the start of the line (allowing up to 3 leading spaces). Otherwise returns nil.
  package static func findMarkerEndIndex(in tokens: [any CodeToken<MarkdownTokenElement>]) -> Int? {
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if leadingSpaces > 3 { return nil }

    var i = 0
    while i < tokens.count && tokens[i].element == .whitespace { i += 1 }
    guard i < tokens.count else { return nil }
    let t = tokens[i]
    if t.element == .backslash { return nil }
    guard t.element == .gt else { return nil }
    i += 1
    // Optional single whitespace after '>'
    if i < tokens.count, tokens[i].element == .whitespace { i += 1 }
    return i
  }

  /// Parse leading blockquote markers. Returns (depth, contentIndex).
  /// Allows up to three leading spaces before the first '>' and an optional single
  /// space after each '>' marker.
  package static func parseMarkers(in tokens: [any CodeToken<MarkdownTokenElement>]) -> (Int, Int) {
    var i = 0
    var depth = 0
    // Up to 3 leading spaces
    if i < tokens.count, tokens[i].element == .whitespace {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return (0, 0) }
      i += 1
    }
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .backslash { break }
      if t.element == .gt {
        depth += 1
        i += 1
        if i < tokens.count, tokens[i].element == .whitespace { i += 1 }
        continue
      }
      break
    }
    return (depth, i)
  }
}

import CodeParserCore
import Foundation

package enum MarkdownSetextUtils {
  /// Parse a setext underline line. Returns the heading level (1 for '=', 2 for '-')
  /// if the tokens form a valid underline; otherwise returns nil.
  static func headingLevel(for tokens: [any CodeToken<MarkdownTokenElement>]) -> Int? {
    var i = 0
    guard !tokens.isEmpty else { return nil }

    // Up to 3 leading spaces
    if i < tokens.count, tokens[i].element == .whitespace {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return nil }
      i += 1
    }

    // Require a run of '=' or '-' with NO internal spaces between markers
    var marker: MarkdownTokenElement? = nil
    var count = 0
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .backslash { return nil }
      if t.element == .equals || t.element == .dash {
        if marker == nil { marker = t.element }
        if t.element != marker { return nil }
        count += 1
        i += 1
        continue
      }
      // Allow trailing spaces; then must be newline/eof only
      if t.element == .whitespace {
        i += 1
        while i < tokens.count, tokens[i].element == .whitespace { i += 1 }
        break
      }
      if t.element == .newline || t.element == .eof { break }
      // Any other token disqualifies setext underline
      return nil
    }

    // After loop, remaining tokens must be only newline/eof (if any)
    var j = i
    while j < tokens.count {
      let t = tokens[j]
      if t.element == .newline || t.element == .eof { j += 1; continue }
      // Any non-space/non-lineend after marker disqualifies
      return nil
    }

    guard count >= 1, let m = marker else { return nil }
    return (m == .equals) ? 1 : 2
  }
}

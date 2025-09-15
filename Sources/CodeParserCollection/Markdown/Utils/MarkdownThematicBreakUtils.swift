import CodeParserCore
import Foundation

package enum MarkdownThematicBreakUtils {
  /// Returns true if the tokens form a thematic break line (***, --- or ___)
  /// allowing up to 3 leading spaces and arbitrary internal spaces between markers.
  package static func isThematicBreakLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var i = 0
    if i < tokens.count, tokens[i].element == .whitespace {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return false }
      i += 1
    }

    var marker: MarkdownTokenElement? = nil
    var count = 0
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .whitespace { i += 1; continue }
      if t.element == .backslash { return false }
      if t.element == .dash || t.element == .underscore || t.element == .asterisk {
        if marker == nil { marker = t.element }
        if t.element != marker { return false }
        count += 1
        i += 1
        continue
      }
      if t.element == .newline || t.element == .eof { break }
      return false
    }
    return count >= 3 && marker != nil
  }
}

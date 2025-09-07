import CodeParserCore
import Foundation

package enum MarkdownFenceUtils {
  /// Detects a fenced code fence (``` or ~~~) at start of line (after up to 3 spaces)
  package static func isFencedCodeFenceLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var i = 0
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return false }
      i += 1
    }
    guard i < tokens.count, tokens[i].element == .punctuation else { return false }
    let ch = tokens[i].text
    guard ch == "`" || ch == "~" else { return false }
    var count = 0
    while i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == ch {
      count += 1
      i += 1
    }
    return count >= 3
  }
}


import CodeParserCore
import Foundation

enum MarkdownLineReader {
  static func nextLine(
    from tokens: [any CodeToken<MarkdownTokenElement>], startingAt index: Int
  ) -> (String, Int) {
    var line = ""
    var consumed = 0
    var idx = index
    while idx < tokens.count {
      let token = tokens[idx]
      line.append(token.text)
      consumed += 1
      idx += 1
      if token.element == .newline || token.element == .eof {
        break
      }
    }
    return (line, consumed)
  }
}

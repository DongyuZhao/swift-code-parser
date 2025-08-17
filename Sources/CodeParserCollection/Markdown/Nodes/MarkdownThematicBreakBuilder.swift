import CodeParserCore
import Foundation

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

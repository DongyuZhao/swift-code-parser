import CodeParserCore
import Foundation

// MARK: - ATX Heading Builder
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
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
    let node = HeaderNode(level: hashes)
  let inlineParser = MarkdownInlineBuilder()
    var inlineCtx = CodeConstructContext<Node, Token>(
      current: node,
      tokens: Array(inlineTokens),
      consuming: 0,
      state: context.state,
      errors: []
    )
    _ = inlineParser.build(from: &inlineCtx)
    context.current.append(node)
    if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }
    context.consuming = idx
    return true
  }
}

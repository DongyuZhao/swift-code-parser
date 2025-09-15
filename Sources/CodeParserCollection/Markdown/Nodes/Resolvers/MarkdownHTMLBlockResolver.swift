import CodeParserCore
import Foundation

public class MarkdownHTMLBlockCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }
    let tokens = context.tokens
    var i = 0
    if i < tokens.count, tokens[i].element == .whitespace {
      let spaces = tokens[i].text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaces > 3 { return false }
      i += 1
    }
    guard i + 3 < tokens.count else { return false }
    if tokens[i].element == .backslash { return false }
    guard tokens[i].element == .lt else { return false }
    guard tokens[i+1].element == .exclamation else { return false }
    guard tokens[i+2].element == .dash else { return false }
    guard tokens[i+3].element == .dash else { return false }
    var end = tokens.count - 1
    if tokens[end].element == .newline || tokens[end].element == .eof { end -= 1 }
    guard end >= 2 else { return false }
    guard tokens[end-2].element == .dash,
          tokens[end-1].element == .dash,
          tokens[end].element == .gt else { return false }
    let content = tokens[i...end].map { $0.text }.joined()
    if let parent = context.current as? MarkdownNodeBase {
      parent.append(HTMLBlockNode(name: "", content: content))
      context.tokens = []
      return true
    }
    return false
  }
}

import CodeParserCore
import Foundation

// MARK: - Code Block Builder (indented)
public class MarkdownCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .whitespaces, spaces < 4 {
      spaces += tokens[idx].text.count
      idx += 1
    }
    if spaces < 4 { return false }
    // capture until newline
    var lineTokens: [any CodeToken<Token>] = []
    var scan = idx
    while scan < tokens.count {
      let t = tokens[scan]
      if t.element == .newline || t.element == .eof { break }
      lineTokens.append(t)
      scan += 1
    }
    let text = tokensToString(lineTokens[lineTokens.startIndex..<lineTokens.endIndex])
    let node = CodeBlockNode(source: text)
    context.current.append(node)
    if scan < tokens.count, tokens[scan].element == .newline { scan += 1 }
    context.consuming = scan
    return true
  }
}

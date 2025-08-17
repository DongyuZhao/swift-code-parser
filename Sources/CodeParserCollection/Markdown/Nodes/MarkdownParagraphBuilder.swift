import CodeParserCore
import Foundation

// MARK: - Paragraph Builder (very simple)
public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var idx = context.consuming
    // Blank line handling
    let (blank, nextIdx) = isBlankLine(tokens, start: idx)
    if blank {
      context.consuming = nextIdx
      return true
    }
    var lineTokens: [any CodeToken<MarkdownTokenElement>] = []
    var isFirstLine = true
    while true {
      var lineEnd = idx
      var lineStartIdx = idx

      // For continuation lines (not first line), skip leading whitespace
      if !isFirstLine {
        var leadingSpaces = 0
        while lineEnd < tokens.count && tokens[lineEnd].element == .whitespaces {
          leadingSpaces += tokens[lineEnd].text.count
          lineEnd += 1
        }
        // Skip up to 3 leading spaces for paragraph continuation
        if leadingSpaces <= 3 {
          lineStartIdx = lineEnd
        }
      }

      // Collect tokens for this line
      lineEnd = lineStartIdx
      while lineEnd < tokens.count, tokens[lineEnd].element != .newline,
        tokens[lineEnd].element != .eof {
        lineTokens.append(tokens[lineEnd])
        lineEnd += 1
      }
      idx = lineEnd
      if idx < tokens.count, tokens[idx].element == .newline { idx += 1 } else { break }
      if idx >= tokens.count { break }
      let (isBlank, _) = isBlankLine(tokens, start: idx)
      if isBlank { break }
      if isATXHeadingStart(tokens, start: idx) { break }
      // thematic break check
      var tmp = context
      tmp.consuming = idx
      let th = MarkdownThematicBreakBuilder()
      if th.build(from: &tmp) { break }

      // Add a soft line break between lines
      if !lineTokens.isEmpty {
        let endRange = tokens[idx-1].range
        lineTokens.append(MarkdownToken(element: .newline, text: "\n", range: endRange))
      }

      isFirstLine = false
    }

    let p = ParagraphNode(range: tokens[context.consuming].range)
  let inlineParser = MarkdownInlineBuilder()
    var inlineCtx = CodeConstructContext<Node, Token>(
      current: p,
      tokens: Array(lineTokens),
      consuming: 0,
      state: context.state,
      errors: []
    )
    _ = inlineParser.build(from: &inlineCtx)
    context.current.append(p)
    context.consuming = idx
    return true
  }
}

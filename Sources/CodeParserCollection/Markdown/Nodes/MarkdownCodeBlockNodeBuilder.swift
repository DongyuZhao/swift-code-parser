import CodeParserCore
import Foundation

/// Builder for fenced code blocks using backtick (```) or tilde (~~~)
/// fences. This is a simplified implementation that does not handle
/// indented code blocks or all edge cases from the specification.
public struct MarkdownCodeBlockNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let start = context.consuming
    guard start < context.tokens.count else { return false }

    var current = start
    // Skip leading spaces
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .whitespaces {
      current += 1
    }

    guard current < context.tokens.count,
          let fenceToken = context.tokens[current] as? MarkdownToken,
          fenceToken.element == .punctuation,
          fenceToken.text == "`" || fenceToken.text == "~" else { return false }
    let fenceChar = fenceToken.text
    var fenceCount = 0
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element == .punctuation, tok.text == fenceChar {
      fenceCount += 1
      current += 1
    }
    guard fenceCount >= 3 else { return false }

    // Optional info string (language) until newline
    var language = ""
    while current < context.tokens.count,
          let tok = context.tokens[current] as? MarkdownToken,
          tok.element != .newline, tok.element != .hardbreak, tok.element != .eof {
      language += tok.text
      current += 1
    }
    if current < context.tokens.count { current += 1 } // consume newline

    // Gather content until closing fence
    var content = ""
    var lineTokens: [MarkdownToken] = []
    while current < context.tokens.count {
      guard let tok = context.tokens[current] as? MarkdownToken else { break }
      if tok.element == .newline || tok.element == .hardbreak || tok.element == .eof {
        // End of line: check if lineTokens represent closing fence
        var i = 0
        while i < lineTokens.count,
              lineTokens[i].element == .whitespaces { i += 1 }
        var closingCount = 0
        while i < lineTokens.count,
              lineTokens[i].element == .punctuation,
              lineTokens[i].text == fenceChar {
          closingCount += 1
          i += 1
        }
        if closingCount >= fenceCount && i == lineTokens.count {
          // reached closing fence
          current += 1
          break
        } else {
          // not closing fence: append lineTokens and newline to content
          content += lineTokens.map { $0.text }.joined()
          content += "\n"
          lineTokens.removeAll()
          current += 1
          continue
        }
      } else {
        lineTokens.append(tok)
        current += 1
      }
    }

    let node = CodeBlockNode(source: content, language: language.trimmingCharacters(in: .whitespaces))
    context.current.append(node)
    context.consuming = current
    return true
  }
}


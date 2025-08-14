import CodeParserCore
import Foundation

/// Parses block-level formulas delimited by `$$` or `\[ ... \]` pairs.
public class MarkdownFormulaBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    // Allow up to three spaces of indentation
    let (indent, afterIndent) = consumeIndentation(tokens, start: idx)
    if indent > 3 { return false }
    idx = afterIndent
    guard idx < tokens.count else { return false }

    // $$ ... $$ block
    if tokens[idx].element == .dollar {
      var j = idx
      var count = 0
      while j < tokens.count && tokens[j].element == .dollar {
        count += 1
        j += 1
      }
      if count >= 2 {
        let start = j
        var k = j
        var closing: Int? = nil
        while k < tokens.count {
          if tokens[k].element == .dollar {
            var run = 0
            var m = k
            while m < tokens.count && tokens[m].element == .dollar {
              run += 1
              m += 1
            }
            if run >= 2 {
              closing = k
              k = m
              break
            }
            k = m
          } else {
            k += 1
          }
        }
        let exprTokens: [any CodeToken<MarkdownTokenElement>]
        if let close = closing {
          exprTokens = Array(tokens[start..<close])
          idx = k
        } else {
          exprTokens = Array(tokens[start..<tokens.count])
          idx = tokens.count
        }
        if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }
        let expression = exprTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        let node = FormulaBlockNode(expression: expression)
        context.current.append(node)
        context.consuming = idx
        if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
        return true
      }
    }

    // \[ ... \] block
    if tokens[idx].element == .backslash, idx + 1 < tokens.count, tokens[idx + 1].element == .leftBracket {
      var k = idx + 2
      var closing: Int? = nil
      while k + 1 < tokens.count {
        if tokens[k].element == .backslash && tokens[k + 1].element == .rightBracket {
          closing = k
          break
        }
        k += 1
      }
      let exprTokens: [any CodeToken<MarkdownTokenElement>]
      if let close = closing {
        exprTokens = Array(tokens[idx + 2..<close])
        idx = close + 2
      } else {
        exprTokens = Array(tokens[idx + 2..<tokens.count])
        idx = tokens.count
      }
      if idx < tokens.count, tokens[idx].element == .newline { idx += 1 }
      let expression = exprTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
      let node = FormulaBlockNode(expression: expression)
      context.current.append(node)
      context.consuming = idx
      if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
      return true
    }

    return false
  }
}

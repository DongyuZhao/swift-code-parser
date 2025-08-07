import CodeParserCore
import Foundation

public class MarkdownFormulaBlockBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let startIndex = context.consuming
    guard let start = context.tokens[startIndex] as? MarkdownToken else { return false }

    // Detect $$ ... $$
    if start.element == .text && start.text == "$" {
      // ensure next is also '$'
      if startIndex + 1 < context.tokens.count,
        let next = context.tokens[startIndex + 1] as? MarkdownToken, next.element == .text,
        next.text == "$"
      {
        // scan until closing $$ or EOF
        var i = startIndex + 2
        var closeAt: Int? = nil
        while i < context.tokens.count {
          guard let t = context.tokens[i] as? MarkdownToken else { break }
          if t.element == .text && t.text == "$" {
            if i + 1 < context.tokens.count,
              let t2 = context.tokens[i + 1] as? MarkdownToken, t2.element == .text,
              t2.text == "$"
            {
              closeAt = i + 2
              break
            }
          }
          i += 1
        }
        let endIndex = closeAt ?? context.tokens.count
        let raw = joinText(context.tokens, from: startIndex, to: endIndex)
        context.consuming = endIndex
        let expr = trimFormula(raw)
        let node = FormulaBlockNode(expression: expr)
        context.current.append(node)
        // consume one trailing newline if present
        if context.consuming < context.tokens.count,
          let nl = context.tokens[context.consuming] as? MarkdownToken, nl.element == .newline
        {
          context.consuming += 1
        }
        return true
      }
    }

    // Detect \[ ... \]
    if start.element == .backslash,
      startIndex + 1 < context.tokens.count,
      let lb = context.tokens[startIndex + 1] as? MarkdownToken, lb.element == .leftBracket
    {
      var i = startIndex + 2
      var closeAt: Int? = nil
      while i < context.tokens.count {
        guard let t = context.tokens[i] as? MarkdownToken else { break }
        if t.element == .backslash,
          i + 1 < context.tokens.count,
          let rb = context.tokens[i + 1] as? MarkdownToken, rb.element == .rightBracket
        {
          closeAt = i + 2
          break
        }
        i += 1
      }
      let endIndex = closeAt ?? context.tokens.count
      let raw = joinText(context.tokens, from: startIndex, to: endIndex)
      context.consuming = endIndex
      let expr = trimFormula(raw)
      let node = FormulaBlockNode(expression: expr)
      context.current.append(node)
      if context.consuming < context.tokens.count,
        let nl = context.tokens[context.consuming] as? MarkdownToken, nl.element == .newline
      {
        context.consuming += 1
      }
      return true
    }

    return false
  }

  private func trimFormula(_ text: String) -> String {
    var t = text
    if t.hasPrefix("$$") { t.removeFirst(2) }
    if t.hasSuffix("$$") { t.removeLast(2) }
    if t.hasPrefix("\\[") { t.removeFirst(2) }
    if t.hasSuffix("\\]") { t.removeLast(2) }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func joinText(
    _ tokens: [any CodeToken<MarkdownTokenElement>], from: Int, to: Int
  ) -> String {
    var s = ""
    var i = from
    while i < to {
      if let t = tokens[i] as? MarkdownToken {
        s += t.text
      }
      i += 1
    }
    return s
  }
}

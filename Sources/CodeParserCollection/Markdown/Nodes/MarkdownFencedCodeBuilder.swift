import CodeParserCore
import Foundation

public class MarkdownFencedCodeBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .fencedCodeBlock,
      isStartOfLine(context)
    else { return false }
    context.consuming += 1
    let (code, language) = extractCodeAndLanguage(token.text)
    let node = CodeBlockNode(source: code, language: language)
    context.current.append(node)
    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
    return true
  }

  private func extractCodeAndLanguage(_ text: String) -> (String, String?) {
    var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard !lines.isEmpty else { return (text, nil) }
    let fenceLine = String(lines.first!)
    let fenceChar = fenceLine.first ?? "`"
    let fenceCount = fenceLine.prefix { $0 == fenceChar }.count
    // language part: chars after opening fence run up to space or end
    var lang: String? = nil
    let afterFenceSub = fenceLine.dropFirst(fenceCount)
    if !afterFenceSub.isEmpty {
      let trimmed = String(afterFenceSub).trimmingCharacters(in: .whitespaces)
      if let stop = trimmed.firstIndex(where: { $0.isWhitespace || $0 == "{" }) {
        let candidate = trimmed[..<stop]
        lang = candidate.isEmpty ? nil : String(candidate)
      } else {
        lang = trimmed.isEmpty ? nil : trimmed
      }
    }
    // Unescape backslashes in language info (CommonMark: backslash escapes in info string)
    if let l = lang {
      lang = MarkdownEscaping.unescapeBackslashes(l)
    }
    // remove first fence line
    lines.removeFirst()
    // remove closing fence if present
    if let last = lines.last {
      let trimmed = last.trimmingCharacters(in: .whitespaces)
      let closingCount = trimmed.prefix { $0 == fenceChar }.count
      if closingCount >= fenceCount && trimmed.allSatisfy({ $0 == fenceChar }) {
        lines.removeLast()
      }
    }
    return (lines.joined(separator: "\n"), lang)
  }

  private func isStartOfLine(
    _ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    if context.consuming == 0 { return true }
    if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
      return prev.element == .newline
    }
    return false
  }

}

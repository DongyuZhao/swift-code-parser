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
    let code = trimFence(token.text)
    let language = extractLanguage(token.text)
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

  private func trimFence(_ text: String) -> String {
    var lines = text.split(separator: "\n")
    guard lines.count >= 2 else { return text }
    lines.removeFirst()
    if let last = lines.last, last.starts(with: "```") {
      lines.removeLast()
    }
    return lines.joined(separator: "\n")
  }

  private func extractLanguage(_ text: String) -> String? {
    guard let firstLine = text.split(separator: "\n", maxSplits: 1).first else {
      return nil
    }
    var cleaned = firstLine.trimmingCharacters(in: .whitespaces)
    while cleaned.starts(with: "`") {
      cleaned.removeFirst()
    }
    let lang = cleaned.trimmingCharacters(in: .whitespaces)
    return lang.isEmpty ? nil : lang
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

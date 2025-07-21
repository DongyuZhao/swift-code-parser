import Foundation

public class MarkdownCustomContainerBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              isStartOfLine(context),
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .customContainer else { return false }

        context.consuming += 1

        let (name, content) = parseContainer(token.text)
        let node = CustomContainerNode(name: name, content: content)
        context.current.append(node)

        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }

        return true
    }

    private func parseContainer(_ text: String) -> (String, String) {
        var lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
        guard !lines.isEmpty else { return ("", "") }
        var first = String(lines.removeFirst())
        if let range = first.range(of: ":::") {
            first.removeSubrange(range)
        }
        let name = first.trimmingCharacters(in: CharacterSet.whitespaces)
        if let last = lines.last, last.trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix(":::") {
            lines.removeLast()
        }
        let content = lines.joined(separator: "\n")
        return (name, content)
    }

    private func isStartOfLine(_ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        if context.consuming == 0 { return true }
        if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
            return prev.element == .newline
        }
        return false
    }

    private func isStartOfLine(index: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
        if index == 0 { return true }
        if index - 1 < tokens.count,
           let prev = tokens[index - 1] as? MarkdownToken {
            return prev.element == .newline
        }
        return false
    }
}

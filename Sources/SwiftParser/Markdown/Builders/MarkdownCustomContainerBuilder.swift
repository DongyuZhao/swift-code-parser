import Foundation

public class MarkdownCustomContainerBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming + 2 < context.tokens.count,
              isStartOfLine(context),
              let c1 = context.tokens[context.consuming] as? MarkdownToken,
              let c2 = context.tokens[context.consuming + 1] as? MarkdownToken,
              let c3 = context.tokens[context.consuming + 2] as? MarkdownToken,
              c1.element == .colon, c2.element == .colon, c3.element == .colon else { return false }
        var idx = context.consuming + 3
        var name = ""
        while idx < context.tokens.count,
              let t = context.tokens[idx] as? MarkdownToken,
              t.element != .newline {
            name += t.text
            idx += 1
        }
        name = name.trimmingCharacters(in: .whitespaces)
        guard idx < context.tokens.count,
              let nl = context.tokens[idx] as? MarkdownToken,
              nl.element == .newline else { return false }
        idx += 1
        var innerTokens: [any CodeToken<MarkdownTokenElement>] = []
        while idx < context.tokens.count {
            if isStartOfLine(index: idx, tokens: context.tokens),
               idx + 2 < context.tokens.count,
               let e1 = context.tokens[idx] as? MarkdownToken,
               let e2 = context.tokens[idx + 1] as? MarkdownToken,
               let e3 = context.tokens[idx + 2] as? MarkdownToken,
               e1.element == .colon, e2.element == .colon, e3.element == .colon {
                idx += 3
                while idx < context.tokens.count,
                      let t = context.tokens[idx] as? MarkdownToken,
                      t.element != .newline { idx += 1 }
                if idx < context.tokens.count,
                   let nl2 = context.tokens[idx] as? MarkdownToken,
                   nl2.element == .newline { idx += 1 }
                break
            }
            innerTokens.append(context.tokens[idx])
            idx += 1
        }
        context.consuming = idx
        var subContext = CodeContext(current: DocumentNode(), tokens: innerTokens)
        let children = MarkdownInlineParser.parseInline(&subContext)
        let container = CustomContainerNode(name: name)
        for c in children { container.append(c) }
        context.current.append(container)
        return true
    }

    private func isStartOfLine(_ context: CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
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

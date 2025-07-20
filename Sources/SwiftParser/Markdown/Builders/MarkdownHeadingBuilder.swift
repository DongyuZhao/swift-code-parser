import Foundation

public class MarkdownHeadingBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .hash,
              isStartOfLine(context)
        else { return false }

        var level = 0
        var idx = context.consuming
        while idx < context.tokens.count,
              let t = context.tokens[idx] as? MarkdownToken,
              t.element == .hash,
              level < 6 {
            level += 1
            idx += 1
        }
        guard idx < context.tokens.count,
              let space = context.tokens[idx] as? MarkdownToken,
              space.element == .space else { return false }
        idx += 1

        context.consuming = idx
        var children = MarkdownInlineParser.parseInline(&context, stopAt: [.newline])
        let node = HeaderNode(level: level)
        for child in children { node.append(child) }
        context.current.append(node)

        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }

    private func isStartOfLine(_ context: CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        if context.consuming == 0 { return true }
        if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
            return prev.element == .newline
        }
        return false
    }
}

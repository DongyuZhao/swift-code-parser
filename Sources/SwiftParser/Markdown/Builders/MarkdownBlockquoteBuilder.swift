import Foundation

public class MarkdownBlockquoteBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeParseContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .gt,
              isStartOfLine(context) else { return false }
        context.consuming += 1
        // optional leading space
        if context.consuming < context.tokens.count,
           let space = context.tokens[context.consuming] as? MarkdownToken,
           space.element == .space {
            context.consuming += 1
        }
        // Parse inline content until a newline or EOF inside the blockquote
        let children = MarkdownInlineParser.parseInline(&context)
        let node = BlockquoteNode()
        for child in children { node.append(child) }
        context.current.append(node)
        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }

    private func isStartOfLine(_ context: CodeParseContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        if context.consuming == 0 { return true }
        if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
            return prev.element == .newline
        }
        return false
    }
}

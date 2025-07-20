import Foundation

public class MarkdownParagraphBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element != .newline else { return false }

        let node = ParagraphNode(range: token.range)
        let children = MarkdownInlineParser.parseInline(&context, stopAt: [.newline])
        for child in children { node.append(child) }
        context.current.append(node)

        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }
}

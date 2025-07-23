import Foundation
import SwiftParser

public class MarkdownParagraphBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element != .newline,
              token.element != .eof else { return false }

        let node = ParagraphNode(range: token.range)
        // Stop parsing at either a newline or EOF to avoid leftover empty nodes
        let children = MarkdownInlineParser.parseInline(&context)
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

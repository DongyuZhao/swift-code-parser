import Foundation
import CodeParser

public class MarkdownHTMLBlockBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              (token.element == .htmlBlock || token.element == .htmlUnclosedBlock) else { return false }
        context.consuming += 1
        let node = HTMLBlockNode(name: "", content: token.text)
        context.current.append(node)
        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }
}

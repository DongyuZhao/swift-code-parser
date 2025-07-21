import Foundation

public class MarkdownNewlineBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .newline else { return false }
        context.consuming += 1
        context.current = context.current.parent ?? context.current
        return true
    }
}

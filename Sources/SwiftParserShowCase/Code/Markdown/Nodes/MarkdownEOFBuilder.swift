import Foundation
import SwiftParser

/// Consumes trailing EOF tokens without modifying the AST.
public class MarkdownEOFBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .eof else { return false }
        context.consuming += 1
        return true
    }
}

import Foundation
import CodeParser

public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              isStartOfLine(context) else { return false }
        var idx = context.consuming
        var count = 0
        var char: MarkdownTokenElement?
        while idx < context.tokens.count,
              let t = context.tokens[idx] as? MarkdownToken {
            if t.element == .dash || t.element == .asterisk || t.element == .underscore {
                if char == nil { char = t.element }
                if t.element == char {
                    count += 1
                } else {
                    return false
                }
            } else if t.element == .space {
                // ignore
            } else if t.element == .newline || t.element == .eof {
                break
            } else {
                return false
            }
            idx += 1
        }
        guard count >= 3 else { return false }
        context.consuming = idx
        if idx < context.tokens.count,
           let nl = context.tokens[idx] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        let node = ThematicBreakNode()
        context.current.append(node)
        return true
    }

    private func isStartOfLine(_ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        if context.consuming == 0 { return true }
        if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
            return prev.element == .newline
        }
        return false
    }
}

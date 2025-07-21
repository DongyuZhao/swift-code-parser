import Foundation

public class MarkdownAdmonitionBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              isStartOfLine(context),
              let gt = context.tokens[context.consuming] as? MarkdownToken,
              gt.element == .gt else { return false }
        var idx = context.consuming + 1
        if idx < context.tokens.count,
           let space = context.tokens[idx] as? MarkdownToken,
           space.element == .space {
            idx += 1
        }
        guard idx + 3 < context.tokens.count,
              let lb = context.tokens[idx] as? MarkdownToken, lb.element == .leftBracket,
              let ex = context.tokens[idx+1] as? MarkdownToken, ex.element == .exclamation,
              let text = context.tokens[idx+2] as? MarkdownToken, text.element == .text,
              let rb = context.tokens[idx+3] as? MarkdownToken, rb.element == .rightBracket else { return false }
        let kind = text.text.lowercased()
        idx += 4
        guard idx < context.tokens.count,
              let nl = context.tokens[idx] as? MarkdownToken,
              nl.element == .newline else { return false }
        idx += 1
        guard idx < context.tokens.count,
              isStartOfLine(index: idx, tokens: context.tokens),
              let gt2 = context.tokens[idx] as? MarkdownToken,
              gt2.element == .gt else { return false }
        idx += 1
        if idx < context.tokens.count,
           let sp = context.tokens[idx] as? MarkdownToken,
           sp.element == .space { idx += 1 }
        context.consuming = idx
        let children = MarkdownInlineParser.parseInline(&context)
        let node = AdmonitionNode(kind: kind)
        for c in children { node.append(c) }
        context.current.append(node)
        if context.consuming < context.tokens.count,
           let nl2 = context.tokens[context.consuming] as? MarkdownToken,
           nl2.element == .newline { context.consuming += 1 }
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

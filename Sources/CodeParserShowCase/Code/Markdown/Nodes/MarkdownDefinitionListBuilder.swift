import Foundation
import CodeParser

public class MarkdownDefinitionListBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              isStartOfLine(context) else { return false }
        let state = context.state as? MarkdownConstructState ?? MarkdownConstructState()
        if context.state == nil { context.state = state }

        var idx = context.consuming
        var termTokens: [any CodeToken<MarkdownTokenElement>] = []
        while idx < context.tokens.count,
              let t = context.tokens[idx] as? MarkdownToken,
              t.element != .newline {
            termTokens.append(t)
            idx += 1
        }
        guard idx < context.tokens.count,
              let _ = context.tokens[idx] as? MarkdownToken,
              (context.tokens[idx] as! MarkdownToken).element == .newline else {
            state.currentDefinitionList = nil
            return false
        }
        idx += 1
        guard idx < context.tokens.count,
              let colon = context.tokens[idx] as? MarkdownToken,
              colon.element == .colon else {
            state.currentDefinitionList = nil
            return false
        }
        idx += 1
        if idx < context.tokens.count,
           let sp = context.tokens[idx] as? MarkdownToken,
           sp.element == .space {
            idx += 1
        }
        var defTokens: [any CodeToken<MarkdownTokenElement>] = []
        while idx < context.tokens.count,
              let t = context.tokens[idx] as? MarkdownToken,
              t.element != .newline {
            defTokens.append(t)
            idx += 1
        }
        context.consuming = idx
        if idx < context.tokens.count,
           let nl = context.tokens[idx] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }

        let termNode = DefinitionTermNode()
        var termContext = CodeConstructContext(current: termNode, tokens: termTokens, state: context.state)
        let inlineBuilder = MarkdownInlineBuilder(stopAt: [])
        _ = inlineBuilder.build(from: &termContext)

        let descNode = DefinitionDescriptionNode()
        var defContext = CodeConstructContext(current: descNode, tokens: defTokens, state: context.state)
        let inlineBuilder2 = MarkdownInlineBuilder(stopAt: [])
        _ = inlineBuilder2.build(from: &defContext)

        let item = DefinitionItemNode()
        item.append(termNode)
        item.append(descNode)

        if let list = state.currentDefinitionList {
            list.append(item)
        } else {
            let list = DefinitionListNode()
            list.append(item)
            context.current.append(list)
            state.currentDefinitionList = list
        }
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

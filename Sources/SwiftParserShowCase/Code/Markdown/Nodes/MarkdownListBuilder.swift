import Foundation
import SwiftParser

public class MarkdownListBuilder: CodeNodeBuilder {
    public init() {}

    public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count else { return false }
        let state = context.state as? MarkdownContextState ?? MarkdownContextState()
        if context.state == nil { context.state = state }

        var idx = context.consuming
        var indent = 0
        while idx < context.tokens.count,
              let sp = context.tokens[idx] as? MarkdownToken,
              sp.element == .space {
            indent += 1
            idx += 1
        }
        guard idx < context.tokens.count,
              let marker = context.tokens[idx] as? MarkdownToken else { return false }

        var listType: MarkdownNodeElement?
        var markerText = marker.text
        var startNum = 1
        if marker.element == .dash || marker.element == .plus || marker.element == .asterisk {
            listType = .unorderedList
            idx += 1
        } else if marker.element == .number {
            if idx + 1 < context.tokens.count,
               let dot = context.tokens[idx + 1] as? MarkdownToken,
               dot.element == .dot {
                listType = .orderedList
                startNum = Int(marker.text) ?? 1
                markerText += dot.text
                idx += 2
            }
        }
        guard let type = listType else { return false }
        if idx < context.tokens.count,
           let sp = context.tokens[idx] as? MarkdownToken,
           sp.element == .space { idx += 1 } else { return false }

        context.consuming = idx

        while let last = state.listStack.last, last.level > indent {
            state.listStack.removeLast()
            context.current = last.parent ?? context.current
        }

        var listNode: ListNode
        if let last = state.listStack.last, last.level == indent, last.element == type {
            listNode = last
        } else {
            if type == .unorderedList {
                listNode = UnorderedListNode(level: indent)
            } else {
                listNode = OrderedListNode(start: startNum, level: indent)
            }
            context.current.append(listNode)
            state.listStack.append(listNode)
        }
        context.current = listNode

        var isTask = false
        var checked = false
        if context.consuming + 2 < context.tokens.count,
           let lb = context.tokens[context.consuming] as? MarkdownToken,
           lb.element == .leftBracket,
           let status = context.tokens[context.consuming + 1] as? MarkdownToken,
           let rb = context.tokens[context.consuming + 2] as? MarkdownToken,
           rb.element == .rightBracket {
            isTask = true
            if status.element == .text && status.text.lowercased() == "x" {
                checked = true
            }
            context.consuming += 3
            if context.consuming < context.tokens.count,
               let sp = context.tokens[context.consuming] as? MarkdownToken,
               sp.element == .space { context.consuming += 1 }
        }

        let item: MarkdownNodeBase
        if isTask {
            item = TaskListItemNode(checked: checked)
        } else {
            item = ListItemNode(marker: markerText)
        }
        let children = MarkdownInlineParser.parseInline(&context)
        for child in children { item.append(child) }
        listNode.append(item)

        if context.consuming < context.tokens.count,
           let nl = context.tokens[context.consuming] as? MarkdownToken,
           nl.element == .newline {
            context.consuming += 1
        }
        return true
    }
}

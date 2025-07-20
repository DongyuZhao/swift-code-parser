import Foundation

/// Consumer for emphasis and strong emphasis following CommonMark rules
public struct MarkdownEmphasisConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard let mdState = context.state as? MarkdownContextState else { return false }
        guard let mdToken = token as? MarkdownToken else { return false }

        // Only handle emphasis delimiters and EOF for flushing
        if mdToken.isEmphasisDelimiter {
            // Accumulate consecutive delimiters
            if mdState.pendingDelimiterElement == mdToken.element {
                mdState.pendingDelimiterCount += 1
            } else {
                flushPending(state: mdState, context: &context)
                mdState.pendingDelimiterElement = mdToken.element
                mdState.pendingDelimiterCount = 1
            }
            return true
        } else {
            flushPending(state: mdState, context: &context)
            // EOF is consumed here so other consumers don't process it
            if mdToken.element == .eof {
                return true
            }
            return false
        }
    }

    private func flushPending(state: MarkdownContextState, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) {
        guard state.pendingDelimiterCount > 0, let element = state.pendingDelimiterElement else { return }
        var remaining = state.pendingDelimiterCount

        while remaining > 0 {
            if let last = state.openEmphasis.last, last.element == element, last.length <= remaining {
                // Close existing delimiter
                state.openEmphasis.removeLast()
                let parent = last.parent
                let start = last.startIndex
                guard start <= parent.children.count else { continue }
                let children = Array(parent.children[start..<parent.children.count])
                parent.children.removeSubrange(start..<parent.children.count)
                for child in children {
                    if let mdChild = child as? MarkdownNodeBase {
                        last.node.append(mdChild)
                    }
                }
                parent.append(last.node)
                remaining -= last.length
            } else {
                // Open new delimiter
                let length = remaining >= 2 ? 2 : 1
                let newNode: MarkdownNodeBase = length == 2 ? StrongNode(content: "") : EmphasisNode(content: "")
                let parent = context.current as! MarkdownNodeBase
                let startIndex = parent.children.count
                state.openEmphasis.append((node: newNode, parent: parent, startIndex: startIndex, element: element, length: length))
                state.justOpenedDelimiter = true
                remaining -= length
            }
        }

        state.pendingDelimiterCount = 0
        state.pendingDelimiterElement = nil
    }
}

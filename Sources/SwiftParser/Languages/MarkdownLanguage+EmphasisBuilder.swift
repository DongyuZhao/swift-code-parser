import Foundation

extension MarkdownLanguage {
    public class EmphasisBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .star = tok { return true }
            if case .underscore = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            let snap = context.snapshot()
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 1
            let (children, ok) = MarkdownLanguage.parseInline(context: &context, closing: open, count: 1)
            if ok {
                let node = MarkdownEmphasisNode(value: "")
                children.forEach { node.addChild($0) }
                context.currentNode.addChild(node)
            } else {
                context.restore(snap)
                context.currentNode.addChild(MarkdownTextNode(value: open.text))
                context.index += 1
            }
        }
    }

}

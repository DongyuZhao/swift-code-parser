import Foundation

extension MarkdownLanguage {
    public class StrongBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 1 < context.tokens.count else { return false }
            guard let t1 = token as? Token,
                  let t2 = context.tokens[context.index + 1] as? Token else { return false }
            switch (t1, t2) {
            case (.star, .star), (.underscore, .underscore):
                return true
            default:
                return false
            }
        }
        public func build(context: inout CodeContext) {
            let snap = context.snapshot()
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 2
            let (children, ok) = MarkdownLanguage.parseInline(context: &context, closing: open, count: 2)
            if ok {
                let node = MarkdownStrongNode(value: "")
                children.forEach { node.addChild($0) }
                context.currentNode.addChild(node)
            } else {
                context.restore(snap)
                context.currentNode.addChild(MarkdownTextNode(value: open.text + open.text))
                context.index += 2
            }
        }
    }

}

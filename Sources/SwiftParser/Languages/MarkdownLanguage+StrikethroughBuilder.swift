import Foundation

extension MarkdownLanguage {
    public class StrikethroughBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 1 < context.tokens.count else { return false }
            guard let t1 = token as? Token, let t2 = context.tokens[context.index + 1] as? Token else { return false }
            return t1.kindDescription == "~" && t2.kindDescription == "~"
        }
        public func build(context: inout CodeContext) {
            context.index += 2
            var text = ""
            while context.index + 1 < context.tokens.count {
                if let t1 = context.tokens[context.index] as? Token,
                   let t2 = context.tokens[context.index + 1] as? Token,
                   t1.kindDescription == "~" && t2.kindDescription == "~" {
                    context.index += 2
                    context.currentNode.addChild(MarkdownStrikethroughNode(value: text))
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownStrikethroughNode(value: text))
        }
    }

}

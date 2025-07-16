import Foundation

extension MarkdownLanguage {
    public class InlineCodeBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .backtick = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token, case .backtick = tok {
                    context.index += 1
                    let node = MarkdownInlineCodeNode(value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = MarkdownInlineCodeNode(value: text)
            context.currentNode.addChild(node)
        }
    }

}

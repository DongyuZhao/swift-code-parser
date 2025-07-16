import Foundation

extension MarkdownLanguage {
    public class AutoLinkBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .lessThan = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .greaterThan = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownAutoLinkNode(url: text))
        }
    }

}

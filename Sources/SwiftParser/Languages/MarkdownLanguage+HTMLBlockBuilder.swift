import Foundation

extension MarkdownLanguage {
    public class HTMLBlockBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .lessThan = tok, context.index == 0 {
                let rest = String(context.input[tok.range.upperBound...]).lowercased()
                return rest.hasPrefix("!doctype") || rest.hasPrefix("html")
            }
            return false
        }
        public func build(context: inout CodeContext) {
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token { text += tok.text }
                context.index += 1
            }
            let closed = MarkdownLanguage.isHTMLClosed(text)
            context.currentNode.addChild(MarkdownHtmlNode(value: text, closed: closed))
        }
    }

}

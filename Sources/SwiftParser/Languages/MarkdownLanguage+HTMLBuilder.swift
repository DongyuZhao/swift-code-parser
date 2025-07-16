import Foundation

extension MarkdownLanguage {
    public class HTMLBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            return tok.kindDescription == "<"
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip <
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .greaterThan = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            let html = "<" + text + ">"
            let closed = MarkdownLanguage.isHTMLClosed(html)
            context.currentNode.addChild(MarkdownHtmlNode(value: text, closed: closed))
        }
    }

}

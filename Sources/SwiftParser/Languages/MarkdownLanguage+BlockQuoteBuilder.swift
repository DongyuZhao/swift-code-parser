import Foundation

extension MarkdownLanguage {
    public class BlockQuoteBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .greaterThan = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev { return true }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip '>'
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .newline:
                        context.index += 1
                        let node = MarkdownBlockQuoteNode(value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = MarkdownBlockQuoteNode(value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        context.index += 1
                        return
                    default:
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
        }
    }

}

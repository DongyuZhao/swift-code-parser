import Foundation

extension MarkdownLanguage {
    public class ImageBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .exclamation = tok,
               context.index + 1 < context.tokens.count,
               let next = context.tokens[context.index + 1] as? Token,
               case .lbracket = next { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 2 // skip ![
            var alt = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .rbracket = tok { context.index += 1; break }
                    else { alt += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            var url = ""
            if context.index < context.tokens.count, let lp = context.tokens[context.index] as? Token, case .lparen = lp {
                context.index += 1
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        if case .rparen = tok { context.index += 1; break }
                        else { url += tok.text; context.index += 1 }
                    } else { context.index += 1 }
                }
            }
            context.currentNode.addChild(MarkdownImageNode(alt: alt, url: url))
        }
    }

}

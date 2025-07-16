import Foundation

extension MarkdownLanguage {
    public class LinkReferenceDefinitionBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 3 < context.tokens.count else { return false }
            guard let lb = token as? Token,
                  let txt = context.tokens[context.index + 1] as? Token,
                  let rb = context.tokens[context.index + 2] as? Token,
                  let colon = context.tokens[context.index + 3] as? Token else { return false }
            if case .lbracket = lb,
               case .text = txt,
               case .rbracket = rb,
               case .text(let s, _) = colon,
               s.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                return true
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var id = ""
            if context.index < context.tokens.count, let idTok = context.tokens[context.index] as? Token, case .text(let s, _) = idTok {
                id = s
                context.index += 1
            }
            if context.index < context.tokens.count { context.index += 1 } // skip ]
            var text = ""
            if context.index < context.tokens.count, let colon = context.tokens[context.index] as? Token, case .text(let s, _) = colon {
                text = s
                context.index += 1
            }
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .newline = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            var url = text.trimmingCharacters(in: .whitespaces)
            if url.hasPrefix(":") { url.removeFirst() }
            url = url.trimmingCharacters(in: .whitespaces)
            let trimmedID = id.trimmingCharacters(in: .whitespaces)
            context.linkReferences[trimmedID.lowercased()] = url
            context.currentNode.addChild(MarkdownLinkReferenceDefinitionNode(identifier: trimmedID, url: url))
        }
    }
}

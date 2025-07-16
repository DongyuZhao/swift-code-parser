import Foundation

extension MarkdownLanguage {
    public class LinkBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .lbracket = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var textTokens: [Token] = []
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .rbracket = tok {
                        context.index += 1
                        break
                    } else {
                        textTokens.append(tok)
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            let textNodes = MarkdownLanguage.parseInlineTokens(textTokens, input: context.input)
            var url = ""
            if context.index < context.tokens.count, let lparen = context.tokens[context.index] as? Token, case .lparen = lparen {
                context.index += 1
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        if case .rparen = tok {
                            context.index += 1
                            break
                        } else {
                            url += tok.text
                            context.index += 1
                        }
                    } else { context.index += 1 }
                }
            } else if context.index + 2 < context.tokens.count,
                      let lb = context.tokens[context.index] as? Token, case .lbracket = lb,
                      let idTok = context.tokens[context.index + 1] as? Token,
                      let rb = context.tokens[context.index + 2] as? Token, case .rbracket = rb,
                      case .text(let id, _) = idTok {
                context.index += 3
                let key = id.trimmingCharacters(in: .whitespaces).lowercased()
                if let ref = context.linkReferences[key] {
                    url = ref
                }
            }
            let node = MarkdownLinkNode(text: textNodes, url: url)
            context.currentNode.addChild(node)
        }
    }

}

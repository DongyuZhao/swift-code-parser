import Foundation

extension MarkdownLanguage {
    public class IndentedCodeBlockBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .text(let s, _) = tok {
                if (context.index == 0 || (context.tokens[context.index - 1] as? Token)?.kindDescription == "newline") && s.hasPrefix("    ") {
                    return true
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .newline:
                        context.index += 1
                        if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, case .text(let s, _) = next, s.hasPrefix("    ") {
                            text += "\n" + String(s.dropFirst(4))
                            context.index += 1
                        } else {
                            context.currentNode.addChild(MarkdownCodeBlockNode(lang: nil, content: text))
                            return
                        }
                    case .text(let s, _):
                        text += String(s.dropFirst(4))
                        context.index += 1
                    default:
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownCodeBlockNode(lang: nil, content: text))
        }
    }

}

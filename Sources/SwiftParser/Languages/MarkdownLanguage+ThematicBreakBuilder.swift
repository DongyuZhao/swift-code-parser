import Foundation

extension MarkdownLanguage {
    public class ThematicBreakBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            switch tok {
            case .dash, .star, .underscore:
                if context.index == 0 || (context.index > 0 && (context.tokens[context.index - 1] as? Token) is Token && (context.tokens[context.index - 1] as? Token)?.kindDescription == "newline") {
                    var count = 0
                    var idx = context.index
                    while idx < context.tokens.count, let t = context.tokens[idx] as? Token, t.kindDescription == tok.kindDescription {
                        count += 1; idx += 1
                    }
                    if count >= 3 {
                        return true
                    }
                }
            default:
                break
            }
            return false
        }
        public func build(context: inout CodeContext) {
            if context.index < context.tokens.count,
               let tok = context.tokens[context.index] as? Token {
                let kind = tok.kindDescription
                while context.index < context.tokens.count {
                    if let t = context.tokens[context.index] as? Token,
                       t.kindDescription == kind {
                        context.index += 1
                    } else {
                        break
                    }
                }
            }
            if context.index < context.tokens.count,
               let nl = context.tokens[context.index] as? Token,
               case .newline = nl {
                context.index += 1
            }
            context.currentNode.addChild(MarkdownThematicBreakNode(value: ""))
        }
    }

}

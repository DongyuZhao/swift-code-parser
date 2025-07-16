import Foundation

extension MarkdownLanguage {
    public class FootnoteBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let lb = token as? Token, case .lbracket = lb else { return false }
            guard context.index + 2 < context.tokens.count else { return false }
            guard let first = context.tokens[context.index + 1] as? Token else { return false }
            if case .text(let s, _) = first, s.starts(with: "^") {
                var idx = context.index + 2
                while idx < context.tokens.count {
                    if let t = context.tokens[idx] as? Token {
                        if case .rbracket = t { return true }
                        if case .text = t {
                            idx += 1; continue
                        }
                        if case .number = t {
                            idx += 1; continue
                        }
                    }
                    break
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip [
            var id = ""
            while context.index < context.tokens.count {
                guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                if case .rbracket = tok { break }
                id += tok.text
                context.index += 1
            }
            if id.hasPrefix("^") { id.removeFirst() }
            if context.index < context.tokens.count { context.index += 1 } // skip ]

            if context.index < context.tokens.count,
               let colon = context.tokens[context.index] as? Token,
               case .text(let s, _) = colon,
               s.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                var text = s
                context.index += 1
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        if case .newline = tok { context.index += 1; break }
                        else { text += tok.text; context.index += 1 }
                    } else { context.index += 1 }
                }
                if text.hasPrefix(":") { text.removeFirst() }
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                context.currentNode.addChild(MarkdownFootnoteDefinitionNode(identifier: id, text: trimmed))
            } else {
                context.currentNode.addChild(MarkdownFootnoteReferenceNode(identifier: id))
            }
        }
    }
}

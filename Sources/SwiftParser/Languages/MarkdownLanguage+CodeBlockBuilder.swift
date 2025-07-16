import Foundation

extension MarkdownLanguage {
    public class CodeBlockBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let first = token as? Token else { return false }
            let fenceKind: String
            switch first {
            case .backtick: fenceKind = "`"
            case .tilde: fenceKind = "~"
            default: return false
            }
            var idx = context.index
            var count = 0
            while idx < context.tokens.count, let t = context.tokens[idx] as? Token, t.kindDescription == fenceKind {
                count += 1; idx += 1
            }
            guard count >= 3 else { return false }
            if context.index == 0 { return true }
            if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                return true
            }
            return false
        }
        public func build(context: inout CodeContext) {
            guard let startTok = context.tokens[context.index] as? Token else { return }
            let fenceKind = startTok.kindDescription
            var fenceLength = 0
            while context.index < context.tokens.count, let t = context.tokens[context.index] as? Token, t.kindDescription == fenceKind {
                fenceLength += 1
                context.index += 1
            }
            // capture info string until end of line and trim whitespace
            var info = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .newline = tok {
                        context.index += 1
                        break
                    } else {
                        info += tok.text
                        context.index += 1
                    }
                } else {
                    context.index += 1
                }
            }
            info = info.trimmingCharacters(in: .whitespaces)
            let lang = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)

            let blockStart = context.index
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    // check for closing fence at start of line
                    if tok.kindDescription == fenceKind && (context.index == blockStart || (context.index > blockStart && (context.tokens[context.index - 1] as? Token)?.kindDescription == "newline")) {
                        var idx = context.index
                        var count = 0
                        while idx < context.tokens.count, let t = context.tokens[idx] as? Token, t.kindDescription == fenceKind {
                            count += 1; idx += 1
                        }
                        if count >= fenceLength {
                            context.index = idx
                            if context.index < context.tokens.count, let nl = context.tokens[context.index] as? Token, case .newline = nl { context.index += 1 }
                            context.currentNode.addChild(MarkdownCodeBlockNode(lang: lang, content: text))
                            return
                        }
                    }
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownCodeBlockNode(lang: lang, content: text))
        }
    }

}

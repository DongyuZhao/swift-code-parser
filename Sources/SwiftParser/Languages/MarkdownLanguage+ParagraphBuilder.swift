import Foundation

extension MarkdownLanguage {
    public class ParagraphBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            if token is Token { return true } else { return false }
        }
        public func build(context: inout CodeContext) {
            var tokens: [Token] = []
            var ended = false
            var dollarCount = 0  // Track unclosed $ symbols
            while context.index < context.tokens.count {
                guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                switch tok {
                case .text, .star, .underscore, .backtick:
                    tokens.append(tok)
                    context.index += 1
                case .dollar:
                    dollarCount += 1
                    tokens.append(tok)
                    context.index += 1
                case .hardBreak:
                    while let last = tokens.last, case .text(let s, _) = last, s.allSatisfy({ $0 == " " }) {
                        tokens.removeLast()
                    }
                    tokens.append(tok)
                    context.index += 1
                case .newline:
                    context.index += 1
                    ended = true
                case .dash, .hash, .plus, .lbracket,
                     .greaterThan, .exclamation, .tilde, .equal, .lessThan, .ampersand, .semicolon, .pipe:
                    // If we're in an unclosed TeX formula (odd number of $), continue collecting tokens
                    if dollarCount % 2 == 1 {
                        tokens.append(tok)
                        context.index += 1
                    } else {
                        ended = true
                    }
                case .number:
                    if context.index + 1 < context.tokens.count,
                       let dot = context.tokens[context.index + 1] as? Token,
                       case .dot = dot {
                        ended = true
                    } else {
                        tokens.append(tok)
                        context.index += 1
                    }
                case .eof:
                    context.index += 1
                    ended = true
                case .dot, .rbracket, .lparen, .rparen:
                    tokens.append(tok)
                    context.index += 1
                }
                if ended { break }
            }

            // Only create paragraph if we have tokens
            if !tokens.isEmpty {
                let value = tokens.map { $0.text }.joined()
                let children = MarkdownLanguage.parseInlineTokens(tokens, input: context.input)
                let node = MarkdownParagraphNode(value: value)
                children.forEach { node.addChild($0) }
                context.currentNode.addChild(node)
            }
        }
    }
}

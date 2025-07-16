import Foundation

extension MarkdownLanguage {
    public class HeadingBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .hash = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                    return true
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            var count = 0
            while context.index < context.tokens.count,
                  let tok = context.tokens[context.index] as? Token,
                  case .hash = tok,
                  count < 6 {
                count += 1
                context.index += 1
            }
            var tokens: [Token] = []
            while context.index < context.tokens.count {
                guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                switch tok {
                case .newline, .eof:
                    context.index += 1
                default:
                    tokens.append(tok)
                    context.index += 1
                }
                if case .newline = tok { break }
                if case .eof = tok { break }
            }

            // Trim trailing whitespace
            while let last = tokens.last, case .text(let s, _) = last, s.trimmingCharacters(in: .whitespaces).isEmpty {
                tokens.removeLast()
            }
            // Remove trailing '#' sequences
            while let last = tokens.last, case .hash = last {
                tokens.removeLast()
                while let l = tokens.last, case .text(let s, _) = l, s.trimmingCharacters(in: .whitespaces).isEmpty {
                    tokens.removeLast()
                }
            }
            while let last = tokens.last, case .text(let s, _) = last, s.trimmingCharacters(in: .whitespaces).isEmpty {
                tokens.removeLast()
            }

            // Remove spaces before hard breaks
            var processed: [Token] = []
            for tok in tokens {
                if case .hardBreak = tok {
                    while let l = processed.last, case .text(let s, _) = l, s.allSatisfy({ $0 == " " }) {
                        processed.removeLast()
                    }
                }
                processed.append(tok)
            }

            let trimmedValue = processed.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
            let children = MarkdownLanguage.parseInlineTokens(processed, input: context.input)
            let node = MarkdownHeadingNode(value: trimmedValue, level: count)
            children.forEach { node.addChild($0) }
            context.currentNode.addChild(node)
        }
    }

}

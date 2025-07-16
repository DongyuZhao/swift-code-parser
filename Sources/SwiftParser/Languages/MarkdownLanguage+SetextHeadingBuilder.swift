import Foundation

extension MarkdownLanguage {
    public class SetextHeadingBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard token is Token else { return false }
            if context.index > 0 {
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                    // ok
                } else if context.index != 0 {
                    return false
                }
            }

            var idx = context.index
            var sawText = false
            while idx < context.tokens.count {
                guard let t = context.tokens[idx] as? Token else { return false }
                if case .newline = t { break }
                if case .eof = t { return false }
                sawText = true
                idx += 1
            }
            guard sawText else { return false }
            guard idx < context.tokens.count, let nl = context.tokens[idx] as? Token, case .newline = nl else { return false }
            idx += 1
            guard idx < context.tokens.count else { return false }

            var kind: Token?
            var count = 0
            while idx < context.tokens.count {
                guard let tok = context.tokens[idx] as? Token else { return false }
                switch tok {
                case .dash:
                    if kind == nil { kind = tok }
                    if case .dash = kind! { count += 1; idx += 1 } else { return false }
                case .equal:
                    if kind == nil { kind = tok }
                    if case .equal = kind! { count += 1; idx += 1 } else { return false }
                case .text(let s, _):
                    if s.trimmingCharacters(in: .whitespaces).isEmpty { idx += 1 } else { return false }
                case .newline, .eof:
                    break
                default:
                    return false
                }
                if idx < context.tokens.count, let next = context.tokens[idx] as? Token {
                    if case .newline = next { break }
                    if case .eof = next { break }
                }
            }
            if count == 0 { return false }
            if idx < context.tokens.count, let endTok = context.tokens[idx] as? Token {
                switch endTok {
                case .newline, .eof:
                    return true
                default:
                    return false
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .newline = tok {
                        context.index += 1
                        break
                    } else {
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            var level: Int?
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .dash:
                        if level == nil { level = 2 }
                        context.index += 1
                    case .equal:
                        if level == nil { level = 1 }
                        context.index += 1
                    case .text(let s, _) where s.trimmingCharacters(in: .whitespaces).isEmpty:
                        context.index += 1
                    case .newline:
                        context.index += 1
                        let node = MarkdownHeadingNode(value: text.trimmingCharacters(in: .whitespaces), level: level ?? 1)
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        context.index += 1
                        let node = MarkdownHeadingNode(value: text.trimmingCharacters(in: .whitespaces), level: level ?? 1)
                        context.currentNode.addChild(node)
                        return
                    default:
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownHeadingNode(value: text.trimmingCharacters(in: .whitespaces), level: level ?? 1))
        }
    }

    // MARK: - List Parsing

}

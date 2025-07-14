import Foundation

public struct MarkdownLanguage: CodeLanguage {
    public enum Element: String, CodeElement {
        case root
        case paragraph
        case heading
        case text
    }

    public enum Token: CodeToken {
        case text(String, Range<String.Index>)
        case hash(Range<String.Index>)
        case newline(Range<String.Index>)
        case eof(Range<String.Index>)

        public var kindDescription: String {
            switch self {
            case .text: return "text"
            case .hash: return "#"
            case .newline: return "newline"
            case .eof: return "eof"
            }
        }

        public var text: String {
            switch self {
            case .text(let s, _): return s
            case .hash: return "#"
            case .newline: return "\n"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .text(_, let r), .hash(let r), .newline(let r), .eof(let r):
                return r
            }
        }
    }

    public class Tokenizer: CodeTokenizer {
        public init() {}

        public func tokenize(_ input: String) -> [any CodeToken] {
            var tokens: [Token] = []
            var index = input.startIndex
            func advance() { index = input.index(after: index) }
            func add(_ t: Token) { tokens.append(t) }
            while index < input.endIndex {
                let ch = input[index]
                if ch == "#" {
                    let start = index
                    advance()
                    add(.hash(start..<index))
                } else if ch == "\n" {
                    let start = index
                    advance()
                    add(.newline(start..<index))
                } else {
                    let start = index
                    while index < input.endIndex && input[index] != "\n" && input[index] != "#" {
                        advance()
                    }
                    let text = String(input[start..<index])
                    add(.text(text, start..<index))
                }
            }
            let r = index..<index
            tokens.append(.eof(r))
            return tokens
        }
    }

    public class HeadingBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .hash = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            guard context.index < context.tokens.count else { return }
            if let textTok = context.tokens[context.index] as? Token {
                let node = CodeNode(type: Element.heading, value: textTok.text)
                context.currentNode.addChild(node)
                context.index += 1
            }
            // consume newline if exists
            if let nl = context.tokens[context.index] as? Token, case .newline = nl { context.index += 1 }
        }
    }

    public class ParagraphBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            if token is Token { return true } else { return false }
        }
        public func build(context: inout CodeContext) {
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .text(let t, _):
                        text += t
                        context.index += 1
                    case .newline:
                        context.index += 1
                        let node = CodeNode(type: Element.paragraph, value: text)
                        context.currentNode.addChild(node)
                        return
                    case .hash:
                        let node = CodeNode(type: Element.paragraph, value: text)
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = CodeNode(type: Element.paragraph, value: text)
                        context.currentNode.addChild(node)
                        context.index += 1
                        return
                    }
                } else { context.index += 1 }
            }
        }
    }

    public var tokenizer: CodeTokenizer { Tokenizer() }
    public var builders: [CodeElementBuilder] { [HeadingBuilder(), ParagraphBuilder()] }
    public var expressionBuilders: [CodeExpressionBuilder] { [] }
    public var rootElement: any CodeElement { Element.root }
    public init() {}
}

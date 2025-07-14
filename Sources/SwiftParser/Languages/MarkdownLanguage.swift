import Foundation

public struct MarkdownLanguage: CodeLanguage {
    public enum Element: String, CodeElement {
        case root
        case paragraph
        case heading
        case text
        case listItem
        case orderedListItem
        case emphasis
        case strong
        case codeBlock
        case inlineCode
        case link
    }

    public enum Token: CodeToken {
        case text(String, Range<String.Index>)
        case hash(Range<String.Index>)
        case dash(Range<String.Index>)
        case star(Range<String.Index>)
        case underscore(Range<String.Index>)
        case plus(Range<String.Index>)
        case backtick(Range<String.Index>)
        case lbracket(Range<String.Index>)
        case rbracket(Range<String.Index>)
        case lparen(Range<String.Index>)
        case rparen(Range<String.Index>)
        case dot(Range<String.Index>)
        case number(String, Range<String.Index>)
        case newline(Range<String.Index>)
        case eof(Range<String.Index>)

        public var kindDescription: String {
            switch self {
            case .text: return "text"
            case .hash: return "#"
            case .dash: return "-"
            case .star: return "*"
            case .underscore: return "_"
            case .plus: return "+"
            case .backtick: return "`"
            case .lbracket: return "["
            case .rbracket: return "]"
            case .lparen: return "("
            case .rparen: return ")"
            case .dot: return "."
            case .number: return "number"
            case .newline: return "newline"
            case .eof: return "eof"
            }
        }

        public var text: String {
            switch self {
            case .text(let s, _): return s
            case .hash: return "#"
            case .dash: return "-"
            case .star: return "*"
            case .underscore: return "_"
            case .plus: return "+"
            case .backtick: return "`"
            case .lbracket: return "["
            case .rbracket: return "]"
            case .lparen: return "("
            case .rparen: return ")"
            case .dot: return "."
            case .number(let s, _): return s
            case .newline: return "\n"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .text(_, let r), .hash(let r), .dash(let r), .star(let r), .underscore(let r),
                 .plus(let r), .backtick(let r), .lbracket(let r), .rbracket(let r),
                 .lparen(let r), .rparen(let r), .dot(let r), .number(_, let r), .newline(let r), .eof(let r):
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
                } else if ch == "-" {
                    let start = index
                    advance()
                    add(.dash(start..<index))
                } else if ch == "*" {
                    let start = index
                    advance()
                    add(.star(start..<index))
                } else if ch == "_" {
                    let start = index
                    advance()
                    add(.underscore(start..<index))
                } else if ch == "+" {
                    let start = index
                    advance()
                    add(.plus(start..<index))
                } else if ch == "`" {
                    let start = index
                    advance()
                    add(.backtick(start..<index))
                } else if ch == "[" {
                    let start = index
                    advance()
                    add(.lbracket(start..<index))
                } else if ch == "]" {
                    let start = index
                    advance()
                    add(.rbracket(start..<index))
                } else if ch == "(" {
                    let start = index
                    advance()
                    add(.lparen(start..<index))
                } else if ch == ")" {
                    let start = index
                    advance()
                    add(.rparen(start..<index))
                } else if ch == "." {
                    let start = index
                    advance()
                    add(.dot(start..<index))
                } else if ch.isNumber {
                    let start = index
                    while index < input.endIndex && input[index].isNumber { advance() }
                    let text = String(input[start..<index])
                    add(.number(text, start..<index))
                } else if ch == "\n" {
                    let start = index
                    advance()
                    add(.newline(start..<index))
                } else {
                    let start = index
                    while index < input.endIndex &&
                          input[index] != "\n" &&
                          !"#-*+_`[].()".contains(input[index]) &&
                          !input[index].isNumber {
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

    public class ListItemBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            switch tok {
            case .dash, .star, .plus:
                if context.index + 1 < context.tokens.count,
                   let next = context.tokens[context.index + 1] as? Token,
                   case .text(let s, _) = next,
                   s.first?.isWhitespace == true {
                    if context.index == 0 { return true }
                    if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                        return true
                    }
                }
            default:
                break
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip bullet
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                        case .newline:
                        context.index += 1
                        let node = CodeNode(type: Element.listItem, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = CodeNode(type: Element.listItem, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        context.index += 1
                        return
                    default:
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
        }
    }

    public class OrderedListItemBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .number = tok {
                if context.index + 1 < context.tokens.count,
                   let dot = context.tokens[context.index + 1] as? Token,
                   case .dot = dot {
                    if context.index == 0 { return true }
                    if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                        return true
                    }
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 2 // skip number and '.'
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .newline:
                        context.index += 1
                        let node = CodeNode(type: Element.orderedListItem, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = CodeNode(type: Element.orderedListItem, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        context.index += 1
                        return
                    default:
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
        }
    }

    public class CodeBlockBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 2 < context.tokens.count else { return false }
            guard let t1 = token as? Token,
                  let t2 = context.tokens[context.index + 1] as? Token,
                  let t3 = context.tokens[context.index + 2] as? Token else { return false }
            if case .backtick = t1, case .backtick = t2, case .backtick = t3 {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev {
                    return true
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 3 // skip opening ```
            var text = ""
            while context.index + 2 < context.tokens.count {
                if let t1 = context.tokens[context.index] as? Token,
                   let t2 = context.tokens[context.index + 1] as? Token,
                   let t3 = context.tokens[context.index + 2] as? Token,
                   case .backtick = t1, case .backtick = t2, case .backtick = t3 {
                    context.index += 3
                    if let nl = context.tokens[context.index] as? Token, case .newline = nl {
                        context.index += 1
                    }
                    let node = CodeNode(type: Element.codeBlock, value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = CodeNode(type: Element.codeBlock, value: text)
            context.currentNode.addChild(node)
        }
    }

    public class StrongBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 1 < context.tokens.count else { return false }
            guard let t1 = token as? Token,
                  let t2 = context.tokens[context.index + 1] as? Token else { return false }
            switch (t1, t2) {
            case (.star, .star), (.underscore, .underscore):
                return true
            default:
                return false
            }
        }
        public func build(context: inout CodeContext) {
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 2
            var text = ""
            while context.index + 1 < context.tokens.count {
                if let t1 = context.tokens[context.index] as? Token,
                   let t2 = context.tokens[context.index + 1] as? Token,
                   (t1.kindDescription == open.kindDescription && t2.kindDescription == open.kindDescription) {
                    context.index += 2
                    let node = CodeNode(type: Element.strong, value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = CodeNode(type: Element.strong, value: text)
            context.currentNode.addChild(node)
        }
    }

    public class EmphasisBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .star = tok { return true }
            if case .underscore = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token,
                   tok.kindDescription == open.kindDescription {
                    context.index += 1
                    let node = CodeNode(type: Element.emphasis, value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = CodeNode(type: Element.emphasis, value: text)
            context.currentNode.addChild(node)
        }
    }

    public class InlineCodeBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .backtick = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token, case .backtick = tok {
                    context.index += 1
                    let node = CodeNode(type: Element.inlineCode, value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = CodeNode(type: Element.inlineCode, value: text)
            context.currentNode.addChild(node)
        }
    }

    public class LinkBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .lbracket = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .rbracket = tok {
                        context.index += 1
                        break
                    } else {
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
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
            }
            let node = CodeNode(type: Element.link, value: text + "|" + url)
            context.currentNode.addChild(node)
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
                    case .dash, .hash, .star, .underscore, .plus, .backtick, .lbracket:
                        let node = CodeNode(type: Element.paragraph, value: text)
                        context.currentNode.addChild(node)
                        return
                    case .number:
                        if context.index + 1 < context.tokens.count,
                           let dot = context.tokens[context.index + 1] as? Token,
                           case .dot = dot {
                            let node = CodeNode(type: Element.paragraph, value: text)
                            context.currentNode.addChild(node)
                            return
                        } else {
                            text += tok.text
                            context.index += 1
                        }
                    case .eof:
                        let node = CodeNode(type: Element.paragraph, value: text)
                        context.currentNode.addChild(node)
                        context.index += 1
                        return
                    case .dot, .rbracket, .lparen, .rparen:
                        // treat as text for now
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
        }
    }

    public var tokenizer: CodeTokenizer { Tokenizer() }
    public var builders: [CodeElementBuilder] {
        [HeadingBuilder(), CodeBlockBuilder(), OrderedListItemBuilder(), ListItemBuilder(), LinkBuilder(), StrongBuilder(), EmphasisBuilder(), InlineCodeBuilder(), ParagraphBuilder()]
    }
    public var expressionBuilders: [CodeExpressionBuilder] { [] }
    public var rootElement: any CodeElement { Element.root }
    public init() {}
}

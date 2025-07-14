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
        case blockQuote
        case thematicBreak
        case image
        case html
        case entity
        case strikethrough
        case table
        case autoLink
        case linkReferenceDefinition
    }

    public enum Token: CodeToken {
        case text(String, Range<String.Index>)
        case hash(Range<String.Index>)
        case dash(Range<String.Index>)
        case star(Range<String.Index>)
        case underscore(Range<String.Index>)
        case plus(Range<String.Index>)
        case backtick(Range<String.Index>)
        case greaterThan(Range<String.Index>)
        case exclamation(Range<String.Index>)
        case tilde(Range<String.Index>)
        case equal(Range<String.Index>)
        case lessThan(Range<String.Index>)
        case ampersand(Range<String.Index>)
        case semicolon(Range<String.Index>)
        case pipe(Range<String.Index>)
        case lbracket(Range<String.Index>)
        case rbracket(Range<String.Index>)
        case lparen(Range<String.Index>)
        case rparen(Range<String.Index>)
        case dot(Range<String.Index>)
        case number(String, Range<String.Index>)
        case softBreak(Range<String.Index>)
        case hardBreak(Range<String.Index>)
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
            case .greaterThan: return ">"
            case .exclamation: return "!"
            case .tilde: return "~"
            case .equal: return "="
            case .lessThan: return "<"
            case .ampersand: return "&"
            case .semicolon: return ";"
            case .pipe: return "|"
            case .lbracket: return "["
            case .rbracket: return "]"
            case .lparen: return "("
            case .rparen: return ")"
            case .dot: return "."
            case .number: return "number"
            case .softBreak: return "softBreak"
            case .hardBreak: return "hardBreak"
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
            case .greaterThan: return ">"
            case .exclamation: return "!"
            case .tilde: return "~"
            case .equal: return "="
            case .lessThan: return "<"
            case .ampersand: return "&"
            case .semicolon: return ";"
            case .pipe: return "|"
            case .lbracket: return "["
            case .rbracket: return "]"
            case .lparen: return "("
            case .rparen: return ")"
            case .dot: return "."
            case .number(let s, _): return s
            case .softBreak: return "\n"
            case .hardBreak: return "\n"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .text(_, let r), .hash(let r), .dash(let r), .star(let r), .underscore(let r),
                 .plus(let r), .backtick(let r), .greaterThan(let r), .exclamation(let r), .tilde(let r),
                 .equal(let r), .lessThan(let r), .ampersand(let r), .semicolon(let r), .pipe(let r),
                 .lbracket(let r), .rbracket(let r), .lparen(let r), .rparen(let r), .dot(let r),
                 .number(_, let r), .softBreak(let r), .hardBreak(let r), .eof(let r):
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
                if ch == "\\" {
                    let start = index
                    advance()
                    if index < input.endIndex {
                        let escaped = input[index]
                        advance()
                        add(.text(String(escaped), start..<index))
                    } else {
                        add(.text("\\", start..<index))
                    }
                } else if ch == "#" {
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
                } else if ch == ">" {
                    let start = index
                    advance()
                    add(.greaterThan(start..<index))
                } else if ch == "!" {
                    let start = index
                    advance()
                    add(.exclamation(start..<index))
                } else if ch == "~" {
                    let start = index
                    advance()
                    add(.tilde(start..<index))
                } else if ch == "=" {
                    let start = index
                    advance()
                    add(.equal(start..<index))
                } else if ch == "<" {
                    let start = index
                    advance()
                    add(.lessThan(start..<index))
                } else if ch == "&" {
                    let start = index
                    advance()
                    add(.ampersand(start..<index))
                } else if ch == ";" {
                    let start = index
                    advance()
                    add(.semicolon(start..<index))
                } else if ch == "|" {
                    let start = index
                    advance()
                    add(.pipe(start..<index))
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
                    if let last = tokens.last as? Token {
                        switch last {
                        case .text(let t, let r) where t.hasSuffix("  "):
                            let newText = String(t.dropLast(2))
                            let newEnd = input.index(r.upperBound, offsetBy: -2)
                            tokens[tokens.count - 1] = .text(newText, r.lowerBound..<newEnd)
                            add(.hardBreak(start..<index))
                        default:
                            add(.softBreak(start..<index))
                        }
                    } else {
                        add(.softBreak(start..<index))
                    }
                } else {
                    let start = index
                    while index < input.endIndex &&
                          input[index] != "\n" &&
                          !"#-*+_`[].()<>!~|;&=\\".contains(input[index]) &&
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
            if let nl = context.tokens[context.index] as? Token {
                if case .softBreak = nl { context.index += 1 }
                else if case .hardBreak = nl { context.index += 1 }
            }
        }
    }

    public class SetextHeadingBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard token is Token else { return false }
            if context.index > 0 {
                if let prev = context.tokens[context.index - 1] as? Token {
                    let kd = prev.kindDescription
                    if kd == "softBreak" || kd == "hardBreak" {
                        // ok
                    } else if context.index != 0 {
                        return false
                    }
                } else if context.index != 0 {
                    return false
                }
            }

            var idx = context.index
            var sawText = false
            while idx < context.tokens.count {
                guard let t = context.tokens[idx] as? Token else { return false }
                if case .softBreak = t { break }
                if case .hardBreak = t { break }
                if case .eof = t { return false }
                sawText = true
                idx += 1
            }
            guard sawText else { return false }
            guard idx < context.tokens.count, let nl = context.tokens[idx] as? Token else { return false }
            if !(nl.kindDescription == "softBreak" || nl.kindDescription == "hardBreak") { return false }
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
                case .softBreak, .hardBreak, .eof:
                    break
                default:
                    return false
                }
                if idx < context.tokens.count, let next = context.tokens[idx] as? Token {
                    if case .softBreak = next { break }
                    if case .hardBreak = next { break }
                }
            }
            if count == 0 { return false }
            if idx < context.tokens.count, let endTok = context.tokens[idx] as? Token {
                switch endTok {
                case .softBreak, .hardBreak, .eof:
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
                    if case .softBreak = tok {
                        context.index += 1
                        break
                    } else if case .hardBreak = tok {
                        context.index += 1
                        break
                    } else {
                        text += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .dash, .equal:
                        context.index += 1
                    case .text(let s, _) where s.trimmingCharacters(in: .whitespaces).isEmpty:
                        context.index += 1
                    case .softBreak, .hardBreak:
                        context.index += 1
                        let node = CodeNode(type: Element.heading, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        context.index += 1
                        let node = CodeNode(type: Element.heading, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    default:
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.heading, value: text.trimmingCharacters(in: .whitespaces)))
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
                    if let prev = context.tokens[context.index - 1] as? Token {
                        let kd = prev.kindDescription
                        if kd == "softBreak" || kd == "hardBreak" { return true }
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
                        case .softBreak, .hardBreak:
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
                    if let prev = context.tokens[context.index - 1] as? Token {
                        let kd = prev.kindDescription
                        if kd == "softBreak" || kd == "hardBreak" { return true }
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
                    case .softBreak, .hardBreak:
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
                if let prev = context.tokens[context.index - 1] as? Token {
                    let kd = prev.kindDescription
                    if kd == "softBreak" || kd == "hardBreak" { return true }
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
                    if let nl = context.tokens[context.index] as? Token {
                        if case .softBreak = nl { context.index += 1 }
                        else if case .hardBreak = nl { context.index += 1 }
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

    public class BlockQuoteBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .greaterThan = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token {
                    let kd = prev.kindDescription
                    if kd == "softBreak" || kd == "hardBreak" { return true }
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip '>'
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .softBreak, .hardBreak:
                        context.index += 1
                        let node = CodeNode(type: Element.blockQuote, value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = CodeNode(type: Element.blockQuote, value: text.trimmingCharacters(in: .whitespaces))
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

    public class IndentedCodeBlockBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .text(let s, _) = tok {
                var prevBreak = false
                if context.index > 0, let prev = context.tokens[context.index - 1] as? Token {
                    prevBreak = prev.kindDescription == "softBreak" || prev.kindDescription == "hardBreak"
                }
                if (context.index == 0 || prevBreak) && s.hasPrefix("    ") {
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
                    case .softBreak, .hardBreak:
                        context.index += 1
                        if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, case .text(let s, _) = next, s.hasPrefix("    ") {
                            text += "\n" + String(s.dropFirst(4))
                            context.index += 1
                        } else {
                            context.currentNode.addChild(CodeNode(type: Element.codeBlock, value: text))
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
            context.currentNode.addChild(CodeNode(type: Element.codeBlock, value: text))
        }
    }

    public class ThematicBreakBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            switch tok {
            case .dash, .star, .underscore:
                let prevKD = (context.index > 0 ? (context.tokens[context.index - 1] as? Token)?.kindDescription : nil)
                if context.index == 0 || prevKD == "softBreak" || prevKD == "hardBreak" {
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
            if let tok = context.tokens[context.index] as? Token {
                let kind = tok.kindDescription
                while context.index < context.tokens.count {
                    if let t = context.tokens[context.index] as? Token, t.kindDescription == kind {
                        context.index += 1
                    } else {
                        break
                    }
                }
            }
            if let nl = context.tokens[context.index] as? Token {
                if case .softBreak = nl { context.index += 1 }
                else if case .hardBreak = nl { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.thematicBreak, value: ""))
        }
    }

    public class ImageBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .exclamation = tok,
               context.index + 1 < context.tokens.count,
               let next = context.tokens[context.index + 1] as? Token,
               case .lbracket = next { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 2 // skip ![
            var alt = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .rbracket = tok { context.index += 1; break }
                    else { alt += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            var url = ""
            if context.index < context.tokens.count, let lp = context.tokens[context.index] as? Token, case .lparen = lp {
                context.index += 1
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        if case .rparen = tok { context.index += 1; break }
                        else { url += tok.text; context.index += 1 }
                    } else { context.index += 1 }
                }
            }
            context.currentNode.addChild(CodeNode(type: Element.image, value: alt + "|" + url))
        }
    }

    public class HTMLBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            return tok.kindDescription == "<"
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip <
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .greaterThan = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.html, value: text))
        }
    }

    public class EntityBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .ampersand = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .semicolon = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.entity, value: text))
        }
    }

    public class StrikethroughBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 1 < context.tokens.count else { return false }
            guard let t1 = token as? Token, let t2 = context.tokens[context.index + 1] as? Token else { return false }
            return t1.kindDescription == "~" && t2.kindDescription == "~"
        }
        public func build(context: inout CodeContext) {
            context.index += 2
            var text = ""
            while context.index + 1 < context.tokens.count {
                if let t1 = context.tokens[context.index] as? Token,
                   let t2 = context.tokens[context.index + 1] as? Token,
                   t1.kindDescription == "~" && t2.kindDescription == "~" {
                    context.index += 2
                    context.currentNode.addChild(CodeNode(type: Element.strikethrough, value: text))
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.strikethrough, value: text))
        }
    }

    public class AutoLinkBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .lessThan = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .greaterThan = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            context.currentNode.addChild(CodeNode(type: Element.autoLink, value: text))
        }
    }

    public class TableBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .pipe = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token {
                    let kd = prev.kindDescription
                    if kd == "softBreak" || kd == "hardBreak" { return true }
                }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            var cells: [String] = []
            var cell = ""
            context.index += 1 // skip first pipe
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .pipe:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        cell = ""
                        context.index += 1
                    case .softBreak, .hardBreak:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        context.index += 1
                        context.currentNode.addChild(CodeNode(type: Element.table, value: cells.joined(separator: "|")))
                        return
                    case .eof:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        context.index += 1
                        context.currentNode.addChild(CodeNode(type: Element.table, value: cells.joined(separator: "|")))
                        return
                    default:
                        cell += tok.text
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
        }
    }

    public class FootnoteBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 3 < context.tokens.count else { return false }
            guard let lb = token as? Token,
                  let txt = context.tokens[context.index + 1] as? Token,
                  let rb = context.tokens[context.index + 2] as? Token else { return false }
            if case .lbracket = lb,
               case .text(let s, _) = txt, s.starts(with: "^") ,
               case .rbracket = rb {
                return true
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 3 // skip [^x]
            if context.index < context.tokens.count, let colon = context.tokens[context.index] as? Token, case .text(let s, _) = colon, s.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                var text = s
                context.index += 1
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        if case .softBreak = tok { context.index += 1; break }
                        else if case .hardBreak = tok { context.index += 1; break }
                        else { text += tok.text; context.index += 1 }
                    } else { context.index += 1 }
                }
                context.currentNode.addChild(CodeNode(type: Element.text, value: text.trimmingCharacters(in: .whitespaces)))
            }
        }
    }

    public class LinkReferenceDefinitionBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 3 < context.tokens.count else { return false }
            guard let lb = token as? Token,
                  let txt = context.tokens[context.index + 1] as? Token,
                  let rb = context.tokens[context.index + 2] as? Token,
                  let colon = context.tokens[context.index + 3] as? Token else { return false }
            if case .lbracket = lb,
               case .text = txt,
               case .rbracket = rb,
               case .text(let s, _) = colon,
               s.trimmingCharacters(in: .whitespaces).hasPrefix(":") {
                return true
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var id = ""
            if context.index < context.tokens.count, let idTok = context.tokens[context.index] as? Token, case .text(let s, _) = idTok {
                id = s
                context.index += 1
            }
            if context.index < context.tokens.count { context.index += 1 } // skip ]
            var text = ""
            if context.index < context.tokens.count, let colon = context.tokens[context.index] as? Token, case .text(let s, _) = colon {
                text = s
                context.index += 1
            }
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .softBreak = tok { context.index += 1; break }
                    else if case .hardBreak = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            var url = text.trimmingCharacters(in: .whitespaces)
            if url.hasPrefix(":") { url.removeFirst() }
            url = url.trimmingCharacters(in: .whitespaces)
            context.linkReferences[id.trimmingCharacters(in: .whitespaces).lowercased()] = url
            context.currentNode.addChild(CodeNode(type: Element.linkReferenceDefinition, value: id + "|" + url))
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
                    case .softBreak:
                        text += " "
                        context.index += 1
                    case .hardBreak:
                        text += "\n"
                        context.index += 1
                    case .dash, .hash, .star, .underscore, .plus, .backtick, .lbracket,
                         .greaterThan, .exclamation, .tilde, .equal, .lessThan, .ampersand, .semicolon, .pipe:
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
        [HeadingBuilder(), SetextHeadingBuilder(), CodeBlockBuilder(), IndentedCodeBlockBuilder(), BlockQuoteBuilder(), ThematicBreakBuilder(), OrderedListItemBuilder(), ListItemBuilder(), ImageBuilder(), HTMLBuilder(), EntityBuilder(), StrikethroughBuilder(), AutoLinkBuilder(), TableBuilder(), FootnoteBuilder(), LinkReferenceDefinitionBuilder(), LinkBuilder(), StrongBuilder(), EmphasisBuilder(), InlineCodeBuilder(), ParagraphBuilder()]
    }
    public var expressionBuilders: [CodeExpressionBuilder] { [] }
    public var rootElement: any CodeElement { Element.root }
    public init() {}
}

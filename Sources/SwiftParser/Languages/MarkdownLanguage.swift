import Foundation

public struct MarkdownLanguage: CodeLanguage {
    public enum Element: String, CodeElement {
        case root
        case paragraph
        case heading
        case text
        case listItem
        case orderedListItem
        case unorderedList
        case orderedList
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
        case tableHeader
        case tableRow
        case tableCell
        case autoLink
        case linkReferenceDefinition
        case footnoteDefinition
        case footnoteReference
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
        case hardBreak(Range<String.Index>)
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
            case .hardBreak: return "hardBreak"
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
            case .hardBreak, .newline: return "\n"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .text(_, let r), .hash(let r), .dash(let r), .star(let r), .underscore(let r),
                 .plus(let r), .backtick(let r), .greaterThan(let r), .exclamation(let r), .tilde(let r),
                 .equal(let r), .lessThan(let r), .ampersand(let r), .semicolon(let r), .pipe(let r),
                 .lbracket(let r), .rbracket(let r), .lparen(let r), .rparen(let r), .dot(let r),
                 .number(_, let r), .hardBreak(let r), .newline(let r), .eof(let r):
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
                    var isHard = false
                    if start > input.startIndex {
                        var i = input.index(before: start)
                        var spaceCount = 0
                        while input[i] == " " {
                            spaceCount += 1
                            if i == input.startIndex { break }
                            i = input.index(before: i)
                        }
                        if spaceCount >= 2 {
                            isHard = true
                        } else if spaceCount == 0 && input[i] == "\\" {
                            isHard = true
                        }
                    }
                    advance()
                    if isHard {
                        add(.hardBreak(start..<index))
                    } else {
                        add(.newline(start..<index))
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

    public class UnorderedListBuilder: CodeElementBuilder {
        public init() {}

        private func lineIndent(before idx: Int, in context: CodeContext) -> Int? {
            if idx == 0 { return 0 }
            var i = idx - 1
            var count = 0
            while i >= 0 {
                guard let tok = context.tokens[i] as? Token else { return nil }
                switch tok {
                case .newline:
                    return count
                case .text(let s, _) where s.allSatisfy({ $0 == " " }):
                    count += s.count
                    i -= 1
                default:
                    return nil
                }
            }
            return count
        }

        private func isBullet(_ tok: Token) -> Bool {
            switch tok {
            case .dash, .star, .plus: return true
            default: return false
            }
        }

        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token, isBullet(tok) else { return false }
            guard context.index + 1 < context.tokens.count,
                  let next = context.tokens[context.index + 1] as? Token,
                  case .text(let s, _) = next, s.first?.isWhitespace == true else {
                return false
            }
            if let ind = lineIndent(before: context.index, in: context) { return ind >= 0 } else { return false }
        }

        public func build(context: inout CodeContext) {
            func parseList(_ indent: Int, _ depth: Int) -> CodeNode {
                let list = MarkdownUnorderedListNode(value: "", level: depth)
                var isLoose = false
                while context.index < context.tokens.count {
                    guard let bullet = context.tokens[context.index] as? Token, isBullet(bullet), lineIndent(before: context.index, in: context) == indent else { break }
                    let (node, loose) = parseItem(indent, depth)
                    if loose { isLoose = true }
                    list.addChild(node)
                }
                list.value = isLoose ? "loose" : "tight"
                return list
            }

            func parseItem(_ indent: Int, _ depth: Int) -> (CodeNode, Bool) {
                var loose = false
                // skip bullet and following whitespace
                context.index += 1
                if context.index < context.tokens.count,
                   let t = context.tokens[context.index] as? Token,
                   case .text(let s, _) = t, s.first?.isWhitespace == true {
                    context.index += 1
                }

                let node = MarkdownListItemNode(value: "")
                var text = ""
                itemLoop: while context.index < context.tokens.count {
                    guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                    switch tok {
                    case .newline:
                        context.index += 1
                        // Check for blank line
                        if context.index < context.tokens.count, let nl = context.tokens[context.index] as? Token, case .newline = nl {
                            loose = true
                            context.index += 1
                        }
                        let start = context.index
                        var spaces = 0
                        if start < context.tokens.count, let sTok = context.tokens[start] as? Token, case .text(let s, _) = sTok, s.allSatisfy({ $0 == " " }) {
                            spaces = s.count
                            context.index += 1
                        }
                        if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, isBullet(next), spaces > indent {
                            let sub = parseList(spaces, depth + 1)
                            node.addChild(sub)
                            if context.index < context.tokens.count, let nextTok = context.tokens[context.index] as? Token, isBullet(nextTok), (lineIndent(before: context.index, in: context) ?? 0) <= indent {
                                break itemLoop
                            }
                        } else if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, isBullet(next), spaces == indent {
                            context.index = start
                            break itemLoop
                        } else if spaces > indent {
                            text += "\n"
                        } else if spaces < indent {
                            context.index = start
                            break itemLoop
                        } else {
                            text += "\n"
                        }
                    case .eof:
                        context.index += 1
                        break itemLoop
                    default:
                        text += tok.text
                        context.index += 1
                    }
                }
                node.value = text.trimmingCharacters(in: .whitespaces)
                return (node, loose)
            }

            if let ind = lineIndent(before: context.index, in: context) {
                let list = parseList(ind, 1)
                context.currentNode.addChild(list)
            }
        }
    }

    public class OrderedListBuilder: CodeElementBuilder {
        public init() {}

        private func lineIndent(before idx: Int, in context: CodeContext) -> Int? {
            if idx == 0 { return 0 }
            var i = idx - 1
            var count = 0
            while i >= 0 {
                guard let tok = context.tokens[i] as? Token else { return nil }
                switch tok {
                case .newline:
                    return count
                case .text(let s, _) where s.allSatisfy({ $0 == " " }):
                    count += s.count
                    i -= 1
                default:
                    return nil
                }
            }
            return count
        }

        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token, case .number = tok else { return false }
            guard context.index + 1 < context.tokens.count,
                  let dot = context.tokens[context.index + 1] as? Token, case .dot = dot else { return false }
            if let _ = lineIndent(before: context.index, in: context) { return true }
            return false
        }

        public func build(context: inout CodeContext) {
            func parseList(_ indent: Int, _ depth: Int) -> CodeNode {
                let list = MarkdownOrderedListNode(value: "", level: depth)
                var isLoose = false
                while context.index < context.tokens.count {
                    guard context.index + 1 < context.tokens.count,
                          let num = context.tokens[context.index] as? Token, case .number = num,
                          let dot = context.tokens[context.index + 1] as? Token, case .dot = dot,
                          lineIndent(before: context.index, in: context) == indent else { break }
                    let (node, loose) = parseItem(indent, depth)
                    if loose { isLoose = true }
                    list.addChild(node)
                }
                list.value = isLoose ? "loose" : "tight"
                return list
            }

            func parseItem(_ indent: Int, _ depth: Int) -> (CodeNode, Bool) {
                var loose = false
                context.index += 2
                if context.index < context.tokens.count,
                   let t = context.tokens[context.index] as? Token,
                   case .text(let s, _) = t, s.first?.isWhitespace == true {
                    context.index += 1
                }

                let node = MarkdownOrderedListItemNode(value: "")
                var text = ""
                itemLoop: while context.index < context.tokens.count {
                    guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                    switch tok {
                    case .newline:
                        context.index += 1
                        if context.index < context.tokens.count, let nl = context.tokens[context.index] as? Token, case .newline = nl {
                            loose = true
                            context.index += 1
                        }
                        let start = context.index
                        var spaces = 0
                        if start < context.tokens.count, let sTok = context.tokens[start] as? Token, case .text(let s, _) = sTok, s.allSatisfy({ $0 == " " }) {
                            spaces = s.count
                            context.index += 1
                        }
                        if context.index + 1 < context.tokens.count,
                           let nextNum = context.tokens[context.index] as? Token, case .number = nextNum,
                           let dot = context.tokens[context.index + 1] as? Token, case .dot = dot,
                           spaces > indent {
                            let sub = parseList(spaces, depth + 1)
                            node.addChild(sub)
                            if context.index + 1 < context.tokens.count,
                               let nextBullet = context.tokens[context.index] as? Token, case .number = nextBullet,
                               let ndot = context.tokens[context.index + 1] as? Token, case .dot = ndot,
                               (lineIndent(before: context.index, in: context) ?? 0) <= indent {
                                break itemLoop
                            }
                        } else if context.index + 1 < context.tokens.count,
                                  let nextNum = context.tokens[context.index] as? Token, case .number = nextNum,
                                  let dot = context.tokens[context.index + 1] as? Token, case .dot = dot,
                                  spaces == indent {
                            context.index = start
                            break itemLoop
                        } else if spaces > indent {
                            text += "\n"
                        } else if spaces < indent {
                            context.index = start
                            break itemLoop
                        } else {
                            text += "\n"
                        }
                    case .eof:
                        context.index += 1
                        break itemLoop
                    default:
                        text += tok.text
                        context.index += 1
                    }
                }
                node.value = text.trimmingCharacters(in: .whitespaces)
                return (node, loose)
            }

            if let ind = lineIndent(before: context.index, in: context) {
                let list = parseList(ind, 1)
                context.currentNode.addChild(list)
            }
        }
    }

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

    public class BlockQuoteBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .greaterThan = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev { return true }
            }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1 // skip '>'
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .newline:
                        context.index += 1
                        let node = MarkdownBlockQuoteNode(value: text.trimmingCharacters(in: .whitespaces))
                        context.currentNode.addChild(node)
                        return
                    case .eof:
                        let node = MarkdownBlockQuoteNode(value: text.trimmingCharacters(in: .whitespaces))
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
            context.currentNode.addChild(MarkdownImageNode(alt: alt, url: url))
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
            context.currentNode.addChild(MarkdownHtmlNode(value: text))
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
            let decoded = decode(text)
            context.currentNode.addChild(MarkdownEntityNode(value: decoded))
        }

        private func decode(_ entity: String) -> String {
            switch entity {
            case "amp": return "&"
            case "lt": return "<"
            case "gt": return ">"
            case "quot": return "\""
            case "apos": return "'"
            default:
                if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                    let hex = entity.dropFirst(2)
                    if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) {
                        return String(Character(scalar))
                    }
                } else if entity.hasPrefix("#") {
                    let num = entity.dropFirst()
                    if let value = UInt32(num), let scalar = UnicodeScalar(value) {
                        return String(Character(scalar))
                    }
                }
                return "&" + entity + ";"
            }
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
                    context.currentNode.addChild(MarkdownStrikethroughNode(value: text))
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            context.currentNode.addChild(MarkdownStrikethroughNode(value: text))
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
            context.currentNode.addChild(MarkdownAutoLinkNode(url: text))
        }
    }

    public class BareAutoLinkBuilder: CodeElementBuilder {
        private static let regex: NSRegularExpression = {
            let pattern = #"^((https?|ftp)://[^\s<>]+|www\.[^\s<>]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})"#
            return try! NSRegularExpression(pattern: pattern, options: [])
        }()

        public init() {}

        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            let start = tok.range.lowerBound
            let text = String(context.input[start...])
            let range = NSRange(location: 0, length: text.utf16.count)
            if let m = Self.regex.firstMatch(in: text, range: range), m.range.location == 0 {
                return true
            }
            return false
        }

        public func build(context: inout CodeContext) {
            guard let tok = context.tokens[context.index] as? Token else { return }
            let start = tok.range.lowerBound
            let text = String(context.input[start...])
            let range = NSRange(location: 0, length: text.utf16.count)
            guard let m = Self.regex.firstMatch(in: text, range: range) else { return }
            let endPos = context.input.index(start, offsetBy: m.range.length)
            let url = String(context.input[start..<endPos])
            context.currentNode.addChild(MarkdownAutoLinkNode(url: url))
            while context.index < context.tokens.count {
                if let t = context.tokens[context.index] as? Token, t.range.upperBound <= endPos {
                    context.index += 1
                } else {
                    break
                }
            }
        }
    }

    public class TableBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .pipe = tok {
                if context.index == 0 { return true }
                if let prev = context.tokens[context.index - 1] as? Token, case .newline = prev { return true }
            }
            return false
        }
        func parseRow(_ context: inout CodeContext) -> [String] {
            var cells: [String] = []
            var cell = ""
            context.index += 1 // skip leading pipe
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    switch tok {
                    case .pipe:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        cell = ""
                        context.index += 1
                    case .newline, .eof:
                        cells.append(cell.trimmingCharacters(in: .whitespaces))
                        if let last = cells.last, last.isEmpty { cells.removeLast() }
                        context.index += 1
                        return cells
                    default:
                        cell += tok.text
                        context.index += 1
                    }
                } else {
                    context.index += 1
                }
            }
            if !cell.isEmpty || !cells.isEmpty {
                cells.append(cell.trimmingCharacters(in: .whitespaces))
            }
            return cells
        }

        func parseDelimiter(_ context: inout CodeContext) -> [String]? {
            guard context.index < context.tokens.count,
                  let first = context.tokens[context.index] as? Token,
                  case .pipe = first else { return nil }
            var snapshot = context.snapshot()
            let cells = parseRow(&context)
            for cell in cells {
                var trimmed = cell.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(":") { trimmed.removeFirst() }
                if trimmed.hasSuffix(":") { trimmed.removeLast() }
                if trimmed.count < 3 { context.restore(snapshot); return nil }
                if !trimmed.allSatisfy({ $0 == "-" }) {
                    context.restore(snapshot); return nil
                }
            }
            return cells
        }

        public func build(context: inout CodeContext) {
            var ctx = context
            let header = parseRow(&ctx)
            let startIndex = ctx.index
            if let _ = parseDelimiter(&ctx) {
                var rows: [[String]] = []
                while ctx.index < ctx.tokens.count,
                      let tok = ctx.tokens[ctx.index] as? Token,
                      case .pipe = tok {
                    rows.append(parseRow(&ctx))
                }

                let table = MarkdownTableNode()
                let headerNode = MarkdownTableHeaderNode()
                for cell in header {
                    let cellNode = MarkdownTableCellNode()
                    cellNode.addChild(MarkdownTextNode(value: cell))
                    headerNode.addChild(cellNode)
                }
                table.addChild(headerNode)

                for row in rows {
                    let rowNode = MarkdownTableRowNode()
                    for cell in row {
                        let cellNode = MarkdownTableCellNode()
                        cellNode.addChild(MarkdownTextNode(value: cell))
                        rowNode.addChild(cellNode)
                    }
                    table.addChild(rowNode)
                }

                context = ctx
                context.currentNode.addChild(table)
            } else {
                context.index = startIndex
                context.currentNode.addChild(MarkdownTableNode(value: header.joined(separator: "|")))
            }
        }
    }

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
                    if case .newline = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            var url = text.trimmingCharacters(in: .whitespaces)
            if url.hasPrefix(":") { url.removeFirst() }
            url = url.trimmingCharacters(in: .whitespaces)
            let trimmedID = id.trimmingCharacters(in: .whitespaces)
            context.linkReferences[trimmedID.lowercased()] = url
            context.currentNode.addChild(MarkdownLinkReferenceDefinitionNode(identifier: trimmedID, url: url))
        }
    }

    // Helper to parse inline content supporting nested emphasis/strong
    static func parseInline(context: inout CodeContext, closing: Token, count: Int) -> ([CodeNode], Bool) {
        var nodes: [CodeNode] = []
        var text = ""
        var closed = false
        func flush() {
            if !text.isEmpty {
                nodes.append(MarkdownTextNode(value: text))
                text = ""
            }
        }
        while context.index < context.tokens.count {
            guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
            // Check for closing delimiter first
            if tok.kindDescription == closing.kindDescription {
                var idx = context.index
                var cnt = 0
                while idx < context.tokens.count, let t = context.tokens[idx] as? Token,
                      t.kindDescription == closing.kindDescription {
                    cnt += 1; idx += 1
                }
                if cnt == count {
                    context.index = idx
                    flush()
                    closed = true
                    break
                }
            }

            // Strong delimiter
            if (tok.kindDescription == "*" || tok.kindDescription == "_") &&
               context.index + 1 < context.tokens.count,
               let next = context.tokens[context.index + 1] as? Token,
               next.kindDescription == tok.kindDescription {
                flush()
                context.index += 2
                let (inner, ok) = parseInline(context: &context, closing: tok, count: 2)
                if ok {
                    let node = MarkdownStrongNode(value: "")
                    inner.forEach { node.addChild($0) }
                    nodes.append(node)
                    continue
                } else {
                    text += tok.text + next.text
                    continue
                }
            }

            // Emphasis delimiter
            if tok.kindDescription == "*" || tok.kindDescription == "_" {
                flush()
                context.index += 1
                let (inner, ok) = parseInline(context: &context, closing: tok, count: 1)
                if ok {
                    let node = MarkdownEmphasisNode(value: "")
                    inner.forEach { node.addChild($0) }
                    nodes.append(node)
                    continue
                } else {
                    text += tok.text
                    continue
                }
            }

            // Inline code
            if tok.kindDescription == "`" {
                flush()
                context.index += 1
                var codeText = ""
                while context.index < context.tokens.count {
                    if let t = context.tokens[context.index] as? Token {
                        if t.kindDescription == "`" {
                            context.index += 1
                            let node = MarkdownInlineCodeNode(value: codeText)
                            nodes.append(node)
                            break
                        } else {
                            codeText += t.text
                            context.index += 1
                        }
                    } else { context.index += 1 }
                }
                continue
            }

            text += tok.text
            context.index += 1
        }
        flush()
        return (nodes, closed)
    }

    /// Parse a sequence of tokens as inline content and return the resulting nodes.
    /// This is a convenience wrapper around `parseInline` that treats the entire
    /// token list as a single inline segment.
    static func parseInlineTokens(_ tokens: [Token], input: String) -> [CodeNode] {
        let eofRange = tokens.last?.range ?? input.startIndex..<input.startIndex
        var ctx = CodeContext(tokens: tokens + [.eof(eofRange)],
                              index: 0,
                              currentNode: CodeNode(type: Element.root, value: ""),
                              errors: [],
                              input: input)
        let closing = Token.eof(eofRange)
        let (nodes, _) = parseInline(context: &ctx, closing: closing, count: 1)
        return nodes
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
            let snap = context.snapshot()
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 2
            let (children, ok) = MarkdownLanguage.parseInline(context: &context, closing: open, count: 2)
            if ok {
                let node = MarkdownStrongNode(value: "")
                children.forEach { node.addChild($0) }
                context.currentNode.addChild(node)
            } else {
                context.restore(snap)
                context.currentNode.addChild(MarkdownTextNode(value: open.text + open.text))
                context.index += 2
            }
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
            let snap = context.snapshot()
            guard let open = context.tokens[context.index] as? Token else { return }
            context.index += 1
            let (children, ok) = MarkdownLanguage.parseInline(context: &context, closing: open, count: 1)
            if ok {
                let node = MarkdownEmphasisNode(value: "")
                children.forEach { node.addChild($0) }
                context.currentNode.addChild(node)
            } else {
                context.restore(snap)
                context.currentNode.addChild(MarkdownTextNode(value: open.text))
                context.index += 1
            }
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
                    let node = MarkdownInlineCodeNode(value: text)
                    context.currentNode.addChild(node)
                    return
                } else if let tok = context.tokens[context.index] as? Token {
                    text += tok.text
                    context.index += 1
                } else { context.index += 1 }
            }
            let node = MarkdownInlineCodeNode(value: text)
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
            var textTokens: [Token] = []
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .rbracket = tok {
                        context.index += 1
                        break
                    } else {
                        textTokens.append(tok)
                        context.index += 1
                    }
                } else { context.index += 1 }
            }
            let textNodes = MarkdownLanguage.parseInlineTokens(textTokens, input: context.input)
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
            let node = MarkdownLinkNode(text: textNodes, url: url)
            context.currentNode.addChild(node)
        }
    }

    public class ParagraphBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            if token is Token { return true } else { return false }
        }
        public func build(context: inout CodeContext) {
            var tokens: [Token] = []
            var ended = false
            while context.index < context.tokens.count {
                guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                switch tok {
                case .text, .star, .underscore, .backtick:
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
                    ended = true
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

            let value = tokens.map { $0.text }.joined()
            let children = MarkdownLanguage.parseInlineTokens(tokens, input: context.input)
            let node = MarkdownParagraphNode(value: value)
            children.forEach { node.addChild($0) }
            context.currentNode.addChild(node)
        }
    }

    public var tokenizer: CodeTokenizer { Tokenizer() }
    public var builders: [CodeElementBuilder] {
        [HeadingBuilder(), SetextHeadingBuilder(), CodeBlockBuilder(), IndentedCodeBlockBuilder(), BlockQuoteBuilder(), ThematicBreakBuilder(), OrderedListBuilder(), UnorderedListBuilder(), ImageBuilder(), HTMLBuilder(), EntityBuilder(), StrikethroughBuilder(), AutoLinkBuilder(), BareAutoLinkBuilder(), TableBuilder(), FootnoteBuilder(), LinkReferenceDefinitionBuilder(), LinkBuilder(), ParagraphBuilder()]
    }
    public var expressionBuilders: [CodeExpressionBuilder] { [] }
    public var rootElement: any CodeElement { Element.root }
    public init() {}
}

import Foundation

public struct PythonLanguage: CodeLanguage {
    public enum Element: String, CodeElement {
        case root
        case statement
        case identifier
        case number
        case string
        case assignment
        case function
        case parameters
        case body
        case expression
    }

    public enum Token: CodeToken {
        case identifier(String, Range<String.Index>)
        case number(String, Range<String.Index>)
        case string(String, Range<String.Index>)
        case keyword(String, Range<String.Index>)
        case equal(Range<String.Index>)
        case colon(Range<String.Index>)
        case comma(Range<String.Index>)
        case plus(Range<String.Index>)
        case minus(Range<String.Index>)
        case star(Range<String.Index>)
        case slash(Range<String.Index>)
        case lparen(Range<String.Index>)
        case rparen(Range<String.Index>)
        case newline(Range<String.Index>)
        case eof(Range<String.Index>)

        public var kindDescription: String {
            switch self {
            case .identifier: return "identifier"
            case .number: return "number"
            case .string: return "string"
            case .keyword(let k, _): return "keyword(\(k))"
            case .equal: return "="
            case .colon: return ":"
            case .comma: return ","
            case .plus: return "+"
            case .minus: return "-"
            case .star: return "*"
            case .slash: return "/"
            case .lparen: return "("
            case .rparen: return ")"
            case .newline: return "newline"
            case .eof: return "eof"
            }
        }

        public var text: String {
            switch self {
            case let .identifier(s, _), let .number(s, _), let .string(s, _), let .keyword(s, _):
                return s
            case .equal: return "="
            case .colon: return ":"
            case .comma: return ","
            case .plus: return "+"
            case .minus: return "-"
            case .star: return "*"
            case .slash: return "/"
            case .lparen: return "("
            case .rparen: return ")"
            case .newline: return "\n"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .identifier(_, let r), .number(_, let r), .string(_, let r), .keyword(_, let r), .equal(let r),
                 .colon(let r), .comma(let r), .plus(let r), .minus(let r), .star(let r), .slash(let r),
                 .lparen(let r), .rparen(let r), .newline(let r), .eof(let r):
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
            func add(_ token: Token) { tokens.append(token) }

            while index < input.endIndex {
                let ch = input[index]
                if ch.isWhitespace {
                    if ch == "\n" {
                        let start = index
                        advance()
                        add(.newline(start..<index))
                    } else {
                        advance()
                    }
                } else if ch.isNumber {
                    let start = index
                    while index < input.endIndex && input[index].isNumber {
                        advance()
                    }
                    let text = String(input[start..<index])
                    add(.number(text, start..<index))
                } else if ch == "\"" || ch == "'" {
                    let quote = ch
                    let start = index
                    advance()
                    while index < input.endIndex && input[index] != quote {
                        advance()
                    }
                    if index < input.endIndex { advance() }
                    let text = String(input[start..<index])
                    add(.string(text, start..<index))
                } else if ch.isLetter || ch == "_" {
                    let start = index
                    while index < input.endIndex && (input[index].isLetter || input[index].isNumber || input[index] == "_") {
                        advance()
                    }
                    let text = String(input[start..<index])
                    if ["def", "return"].contains(text) {
                        add(.keyword(text, start..<index))
                    } else {
                        add(.identifier(text, start..<index))
                    }
                } else {
                    let start = index
                    switch ch {
                    case "=":
                        advance(); add(.equal(start..<index))
                    case ":":
                        advance(); add(.colon(start..<index))
                    case ",":
                        advance(); add(.comma(start..<index))
                    case "+":
                        advance(); add(.plus(start..<index))
                    case "-":
                        advance(); add(.minus(start..<index))
                    case "*":
                        advance(); add(.star(start..<index))
                    case "/":
                        advance(); add(.slash(start..<index))
                    case "(":
                        advance(); add(.lparen(start..<index))
                    case ")":
                        advance(); add(.rparen(start..<index))
                    default:
                        advance()
                    }
                }
            }
            let r = index..<index
            tokens.append(.eof(r))
            return tokens
        }
    }

    struct ExpressionParser {
        private let tokens: [any CodeToken]
        private(set) var index: Int

        init(tokens: [any CodeToken], startIndex: Int) {
            self.tokens = tokens
            self.index = startIndex
        }

        mutating func parse(_ minBP: Int = 0) -> CodeNode? {
            guard index < tokens.count, let first = tokens[index] as? Token else { return nil }
            index += 1
            var left: CodeNode?
            switch first {
            case .number(let text, let range):
                left = CodeNode(type: Element.number, value: text, range: range)
            case .identifier(let text, let range):
                left = CodeNode(type: Element.identifier, value: text, range: range)
            case .lparen:
                left = parse(0)
                if index < tokens.count, let t = tokens[index] as? Token, case .rparen = t { index += 1 }
            default:
                return nil
            }
            guard var l = left else { return nil }
            while index < tokens.count, let op = tokens[index] as? Token, let bp = infixBindingPower(op), bp.left >= minBP {
                index += 1
                let rhs = parse(bp.right) ?? CodeNode(type: Element.number, value: "", range: op.range)
                let opNode = CodeNode(type: Element.expression, value: op.text, range: op.range)
                opNode.addChild(l)
                opNode.addChild(rhs)
                l = opNode
            }
            return l
        }

        private func infixBindingPower(_ token: Token) -> (left: Int, right: Int)? {
            switch token {
            case .plus, .minus:
                return (left: 10, right: 11)
            case .star, .slash:
                return (left: 20, right: 21)
            default:
                return nil
            }
        }
    }

    public class AssignmentBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard context.index + 2 < context.tokens.count else { return false }
            if let tok = context.tokens[context.index] as? Token,
               case .identifier = tok,
               let eq = context.tokens[context.index + 1] as? Token,
               case .equal = eq {
                return true
            }
            return false
        }

        public func build(context: inout CodeContext) {
            guard let identifierTok = context.tokens[context.index] as? Token else { return }
            let node = CodeNode(type: Element.assignment, value: identifierTok.text)
            context.currentNode.addChild(node)
            context.index += 2 // skip identifier and '='

            var parser = ExpressionParser(tokens: context.tokens, startIndex: context.index)
            if let exprNode = parser.parse() {
                node.addChild(exprNode)
                context.index = parser.index
            }
            if context.index < context.tokens.count,
               let nl = context.tokens[context.index] as? Token,
               case .newline = nl {
                context.index += 1
            }
        }
    }

    public class NewlineBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .newline = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
        }
    }

    public class FunctionBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .keyword("def", _) = tok { return true }
            return false
        }

        public func build(context: inout CodeContext) {
            // def name():\n
            context.index += 1 // skip 'def'
            guard let nameTok = context.tokens[context.index] as? Token else { return }
            let funcNode = CodeNode(type: Element.function, value: nameTok.text)
            context.currentNode.addChild(funcNode)
            context.index += 1 // skip name
            // skip params
            if let lparen = context.tokens[context.index] as? Token, case .lparen = lparen {
                context.index += 1
                let paramsNode = CodeNode(type: Element.parameters, value: "")
                funcNode.addChild(paramsNode)
                while context.index < context.tokens.count {
                    if let tok = context.tokens[context.index] as? Token {
                        switch tok {
                        case .identifier:
                            paramsNode.addChild(CodeNode(type: Element.identifier, value: tok.text))
                            context.index += 1
                            if let comma = context.tokens[context.index] as? Token, case .comma = comma {
                                context.index += 1
                            }
                        case .rparen:
                            context.index += 1
                            break
                        default:
                            context.index += 1
                        }
                        if case .rparen = tok { break }
                    }
                }
            }
            if let colon = context.tokens[context.index] as? Token, case .colon = colon {
                context.index += 1
            }
            let bodyNode = CodeNode(type: Element.body, value: "")
            funcNode.addChild(bodyNode)
            // consume until newline or eof
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token, case .newline = tok { context.index += 1; break }
                context.index += 1
            }
        }
    }

    public var tokenizer: CodeTokenizer { Tokenizer() }

    public var builders: [CodeElementBuilder] { [NewlineBuilder(), FunctionBuilder(), AssignmentBuilder()] }

    public var rootElement: any CodeElement { Element.root }

    public init() {}
}

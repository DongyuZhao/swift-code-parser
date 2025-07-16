import Foundation

extension MarkdownLanguage {
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
        case dollar(Range<String.Index>)
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
            case .dollar: return "$"
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
            case .dollar: return "$"
            case .eof: return ""
            }
        }

        public var range: Range<String.Index> {
            switch self {
            case .text(_, let r), .hash(let r), .dash(let r), .star(let r), .underscore(let r),
                 .plus(let r), .backtick(let r), .greaterThan(let r), .exclamation(let r), .tilde(let r),
                 .equal(let r), .lessThan(let r), .ampersand(let r), .semicolon(let r), .pipe(let r),
                 .lbracket(let r), .rbracket(let r), .lparen(let r), .rparen(let r), .dot(let r),
                 .number(_, let r), .hardBreak(let r), .newline(let r), .dollar(let r), .eof(let r):
                return r
            }
        }
    }

}

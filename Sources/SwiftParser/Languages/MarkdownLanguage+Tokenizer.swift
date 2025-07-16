import Foundation

extension MarkdownLanguage {
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
}

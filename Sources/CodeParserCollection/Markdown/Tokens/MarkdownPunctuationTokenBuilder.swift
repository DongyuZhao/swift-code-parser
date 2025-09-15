import CodeParserCore
import Foundation

// MARK: - Punctuation Token Builder
public class MarkdownPunctuationTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    let start = context.consuming

    guard start < source.endIndex else { return false }
    let char = source[start]
    guard MarkdownPunctuationCharacter.characters.contains(char) else { return false }

    // Map character to a specific punctuation element
    let element: MarkdownTokenElement
    switch char {
    case "!": element = .exclamation
    case "\"": element = .quote
    case "#": element = .hash
    case "$": element = .dollar
    case "%": element = .percent
    case "&": element = .ampersand
    case "'": element = .singleQuote
    case "(": element = .leftParen
    case ")": element = .rightParen
    case "*": element = .asterisk
    case "+": element = .plus
    case ",": element = .comma
    case "-": element = .dash
    case ".": element = .dot
    case "/": element = .forwardSlash
    case ":": element = .colon
    case ";": element = .semicolon
    case "<": element = .lt
    case "=": element = .equals
    case ">": element = .gt
    case "?": element = .question
    case "@": element = .atSign
    case "[": element = .leftBracket
    case "\\": element = .backslash
    case "]": element = .rightBracket
    case "^": element = .caret
    case "_": element = .underscore
    case "`": element = .backtick
    case "{": element = .leftBrace
    case "|": element = .pipe
    case "}": element = .rightBrace
    case "~": element = .tilde
    default:
      // Fallback: should not happen as char is known punctuation; do not emit legacy .punctuation
      element = .characters
    }

    let range = start..<source.index(after: start)
    let token = MarkdownToken(element: element, text: String(char), range: range)
    context.tokens.append(token)
    context.consuming = range.upperBound

    return true
  }
}

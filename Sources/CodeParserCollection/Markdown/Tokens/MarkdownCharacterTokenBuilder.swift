import CodeParserCore
import Foundation

@preconcurrency
public class MarkdownCharacterTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  @preconcurrency nonisolated(unsafe) static let characters: [Character: MarkdownTokenElement] = [
    "#": .hash,
    "*": .asterisk,
    "_": .underscore,
    "-": .dash,
    "+": .plus,
    "=": .equals,
    "~": .tilde,
    "^": .caret,
    "@": .atSign,
    "|": .pipe,
    ":": .colon,
    ";": .semicolon,
    "!": .exclamation,
    "?": .question,
    ".": .dot,
    ",": .comma,
    ">": .gt,
    "<": .lt,
    "&": .ampersand,
    "\\": .backslash,
    "/": .forwardSlash,
    "\"": .quote,
    "'": .singleQuote,
    "$": .text,
    "%": .text,
    "[": .leftBracket,
    "]": .rightBracket,
    "(": .leftParen,
    ")": .rightParen,
    "{": .leftBrace,
    "}": .rightBrace,
  ]

  public init() {}

  public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
    guard context.consuming < context.source.endIndex else { return false }
    let char = context.source[context.consuming]
    guard let element = Self.characters[char] else { return false }
    let start = context.consuming
    context.consuming = context.source.index(after: context.consuming)
    let token = MarkdownToken(
      element: element, text: String(char), range: start..<context.consuming)
    context.tokens.append(token)
    return true
  }
}

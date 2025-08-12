import CodeParserCore
import Foundation

// MARK: - Token Element Definition
public enum MarkdownTokenElement: String, CaseIterable, CodeTokenElement {
  // MARK: - Basic Structure
  case hash = "#"
  case asterisk = "*"
  case underscore = "_"
  case dash = "-"
  case plus = "+"
  case equals = "="
  case tilde = "~"
  case caret = "^"
  case atSign = "@"
  case pipe = "|"
  case colon = ":"
  case semicolon = ";"
  case exclamation = "!"
  case question = "?"
  case dot = "."
  case comma = ","
  case gt = ">"
  case lt = "<"
  case ampersand = "&"
  case backslash = "\\"
  case forwardSlash = "/"
  case quote = "\""
  case singleQuote = "'"

  // MARK: - Brackets and Parentheses
  case leftBracket = "["
  case rightBracket = "]"
  case leftParen = "("
  case rightParen = ")"
  case leftBrace = "{"
  case rightBrace = "}"

  // MARK: - Whitespace and Special Characters
  case space = " "
  case tab = "\t"
  case newline = "\n"
  case carriageReturn = "\r"
  case eof = ""

  // MARK: - Text and Numbers
  case text = "text"  // consecutive text characters
  case number = "number"  // consecutive digit characters
}

// MARK: - Token Implementation
public class MarkdownToken: CodeToken {
  public typealias Element = MarkdownTokenElement

  public let element: MarkdownTokenElement
  public let text: String
  public let range: Range<String.Index>

  public init(element: MarkdownTokenElement, text: String, range: Range<String.Index>) {
    self.element = element
    self.text = text
    self.range = range
  }

  // Convenience initializers for common tokens
  public static func hash(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .hash, text: "#", range: range)
  }

  public static func asterisk(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .asterisk, text: "*", range: range)
  }

  public static func underscore(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .underscore, text: "_", range: range)
  }

  public static func dash(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .dash, text: "-", range: range)
  }

  public static func plus(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .plus, text: "+", range: range)
  }

  public static func equals(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .equals, text: "=", range: range)
  }

  public static func tilde(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .tilde, text: "~", range: range)
  }

  public static func atSign(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .atSign, text: "@", range: range)
  }

  public static func pipe(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .pipe, text: "|", range: range)
  }

  public static func colon(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .colon, text: ":", range: range)
  }

  public static func exclamation(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .exclamation, text: "!", range: range)
  }

  public static func gt(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .gt, text: ">", range: range)
  }

  public static func lt(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .lt, text: "<", range: range)
  }

  public static func leftBracket(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .leftBracket, text: "[", range: range)
  }

  public static func rightBracket(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .rightBracket, text: "]", range: range)
  }

  public static func leftParen(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .leftParen, text: "(", range: range)
  }

  public static func rightParen(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .rightParen, text: ")", range: range)
  }

  public static func leftBrace(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .leftBrace, text: "{", range: range)
  }

  public static func rightBrace(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .rightBrace, text: "}", range: range)
  }

  public static func space(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .space, text: " ", range: range)
  }

  public static func tab(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .tab, text: "\t", range: range)
  }

  public static func newline(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .newline, text: "\n", range: range)
  }

  public static func backslash(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .backslash, text: "\\", range: range)
  }

  public static func text(_ text: String, at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .text, text: text, range: range)
  }

  public static func number(_ number: String, at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .number, text: number, range: range)
  }

  public static func eof(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .eof, text: "", range: range)
  }
}

// MARK: - Token Utilities
extension MarkdownToken {
  /// Check if this token is a delimiter that can be used for emphasis
  public var isEmphasisDelimiter: Bool {
    return element == .asterisk || element == .underscore
  }

  /// Check if this token is a whitespace token
  public var isWhitespace: Bool {
    return element == .space || element == .tab || element == .newline || element == .carriageReturn
  }

  /// Check if this token is a line ending
  public var isLineEnding: Bool {
    return element == .newline || element == .carriageReturn
  }

  /// Check if this token is a punctuation character
  public var isPunctuation: Bool {
    switch element {
    case .exclamation, .question, .dot, .comma, .semicolon, .colon, .quote, .singleQuote, .atSign:
      return true
    default:
      return false
    }
  }

  /// Check if this token can start a block element
  public var canStartBlock: Bool {
    switch element {
    case .hash, .gt, .dash, .plus, .asterisk, .tilde, .number:
      return true
    default:
      return false
    }
  }

  /// Check if this token is a math delimiter
  public var isMathDelimiter: Bool {
    return false  // No individual math delimiters anymore, only complete formulas
  }

  /// Check if this token is a table delimiter
  public var isTableDelimiter: Bool {
    return element == .pipe
  }
}

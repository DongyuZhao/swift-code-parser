import CodeParserCore
import Foundation

// MARK: - Token Element Definition
public enum MarkdownTokenElement: String, CaseIterable, CodeTokenElement {
  // Core kinds
  case characters = "characters" // A run of non-whitespace, non-punctuation characters (no escape handling)
  case newline = "newline" // A \n
  case whitespace = "whitespace" // A whitespace character except for newline
  case eof = "eof" // End of file

  // Legacy/compat: generic punctuation (not used by tokenizer anymore)
  case punctuation = "punctuation"

  // Character reference (not produced by tokenizer anymore)
  case charef = "charef"

  // Specific punctuation tokens
  case exclamation
  case quote        // '"'
  case hash         // '#'
  case dollar       // '$'
  case percent      // '%'
  case ampersand    // '&'
  case singleQuote  // '\''
  case leftParen    // '('
  case rightParen   // ')'
  case asterisk     // '*'
  case plus         // '+'
  case comma        // ','
  case dash         // '-'
  case dot          // '.'
  case forwardSlash // '/'
  case colon        // ':'
  case semicolon    // ';'
  case lt           // '<'
  case equals       // '='
  case gt           // '>'
  case question     // '?'
  case atSign       // '@'
  case leftBracket  // '['
  case backslash    // '\\'
  case rightBracket // ']'
  case caret        // '^'
  case underscore   // '_'
  case backtick     // '`'
  case leftBrace    // '{'
  case pipe         // '|'
  case rightBrace   // '}'
  case tilde        // '~'
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
}

extension MarkdownToken {
  public static func eof(at range: Range<String.Index>) -> MarkdownToken {
    return MarkdownToken(element: .eof, text: "", range: range)
  }
}

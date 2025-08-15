// MARK: - Punctuation Characters (ASCII punctuation only)

public enum MarkdownPunctuationCharacter: Character, CaseIterable, Sendable {
  // U+0021–2F
  case exclamation  = "!"
  case quote        = "\""
  case hash         = "#"
  case dollar       = "$"
  case percent      = "%"
  case ampersand    = "&"
  case singleQuote  = "'"
  case leftParen    = "("
  case rightParen   = ")"
  case asterisk     = "*"
  case plus         = "+"
  case comma        = ","
  case dash         = "-"
  case dot          = "."
  case forwardSlash = "/"

  // U+003A–0040
  case colon        = ":"
  case semicolon    = ";"
  case lt           = "<"
  case equals       = "="
  case gt           = ">"
  case question     = "?"
  case atSign       = "@"

  // U+005B–0060
  case leftBracket  = "["
  case backslash    = "\\"
  case rightBracket = "]"
  case caret        = "^"
  case underscore   = "_"
  case backtick     = "`"

  // U+007B–007E
  case leftBrace    = "{"
  case pipe         = "|"
  case rightBrace   = "}"
  case tilde        = "~"
}

extension MarkdownPunctuationCharacter {
  static let characters: Set<Character> = Set(MarkdownPunctuationCharacter.allCases.map { $0.rawValue })
}

// MARK: - Whitespace Characters (used as text boundaries, includes line endings and other CM whitespace)

public enum MarkdownWhitespaceCharacter: Character, CaseIterable, Sendable {
  case space          = " "        // U+0020
  case tab            = "\t"       // U+0009
  case newline        = "\n"       // U+000A (LF)
  case tabulation     = "\u{000B}" // U+000B (VT)
  case formFeed       = "\u{000C}" // U+000C (FF)
  case carriageReturn = "\r"       // U+000D (CR)
}

extension MarkdownWhitespaceCharacter {
  static let characters: Set<Character> = Set(MarkdownWhitespaceCharacter.allCases.map { $0.rawValue })
}

// MARK: - CommonMark -GFM Character Classifications

// Reference: https://github.github.com/gfm/#characters-and-lines
public enum MarkdownCharacter: Sendable {
  public static let whitespaces = MarkdownWhitespaceCharacter.characters

  public static let punctuations = MarkdownPunctuationCharacter.characters

  public static let boundaries = punctuations.union(whitespaces)
}

// MARK: - String Utils

public extension String {
  var end: String.Index {
    return self.endIndex
  }

  func peek(_ index: String.Index) -> Character? {
    if index < self.end {
      return self[index]
    }
    return nil
  }

  func slice(_ range: Range<String.Index>) -> String {
    return String(self[range])
  }
}

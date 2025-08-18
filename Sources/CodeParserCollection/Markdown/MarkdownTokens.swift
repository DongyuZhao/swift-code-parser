import CodeParserCore
import Foundation

// MARK: - Token Element Definition
public enum MarkdownTokenElement: String, CaseIterable, CodeTokenElement {
  case characters = "characters" // A sequence of characters that are not whitespace, punctuation, or EOF. All the escaped punctuations should also be treated as characters.
  case newline = "newline" // A \n, \r, \r\n represent a soft new line.
  case hardbreak = "hardbreak" // A hard break, which is a line ending that will start a new line.
  case whitespaces = "whitespaces" // A sequence of whitespace characters except for new lines.
  case punctuation = "punctuation" // A character that belongs to punctuations
  case charef = "charef" // A sequence of characters that represents an HTML entity reference
  case eof = "eof" // The end of file
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

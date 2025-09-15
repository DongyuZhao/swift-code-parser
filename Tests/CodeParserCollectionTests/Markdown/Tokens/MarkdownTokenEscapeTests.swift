import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tokenization - No Escapes/Refs")
struct MarkdownTokenEscapeTests {
  private let h = MarkdownTestHarness()

  private func tokens(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
    h.parser.parse(input, language: h.language).tokens
  }

  private func pair(_ t: any CodeToken<MarkdownTokenElement>) -> (MarkdownTokenElement, String) {
    (t.element, t.text)
  }

  @Test("Backslashes are punctuation; no escaping")
  func backslash_no_escape() async throws {
    let toks = tokens("\\*a\\&b\n")
    let expected: [(MarkdownTokenElement, String)] = [
      (.backslash, "\\"), (.asterisk, "*"), (.characters, "a"),
      (.backslash, "\\"), (.ampersand, "&"), (.characters, "b"),
      (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  @Test("Characters vs punctuation separation")
  func basic_separation() async throws {
    let toks = tokens("Hello, world!\n")
    let expected: [(MarkdownTokenElement, String)] = [
      (.characters, "Hello"), (.comma, ","), (.whitespace, " "),
      (.characters, "world"), (.exclamation, "!"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }
}

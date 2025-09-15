import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tokenization - Entities are literal")
struct MarkdownTokenEntitiesTests {
  private let h = MarkdownTestHarness()

  private func tokens(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
    h.parser.parse(input, language: h.language).tokens
  }

  private func pair(_ t: any CodeToken<MarkdownTokenElement>) -> (MarkdownTokenElement, String) {
    (t.element, t.text)
  }

  @Test("Named and numeric references remain literal tokens")
  func refs_literal() async throws {
    let toks = tokens("&amp; &ouml; &#10; &#xA9;\n")
    let expected: [(MarkdownTokenElement, String)] = [
      (.ampersand, "&"), (.characters, "amp"), (.semicolon, ";"), (.whitespace, " "),
      (.ampersand, "&"), (.characters, "ouml"), (.semicolon, ";"), (.whitespace, " "),
      (.ampersand, "&"), (.hash, "#"), (.characters, "10"), (.semicolon, ";"), (.whitespace, " "),
      (.ampersand, "&"), (.hash, "#"), (.characters, "xA9"), (.semicolon, ";"),
      (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  @Test("Entity-like forms inside link/title stay literal at token phase")
  func refs_in_link_title_literal() async throws {
    let toks = tokens("[a](url &quot;tit&quot;)\n")
    // No .charef tokens at all; '&' and ';' are punctuation; name is characters
    #expect(!toks.contains { $0.element == .charef })
  }
}

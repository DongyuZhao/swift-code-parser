import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark/GFM - Entity References tokenization (.href)")
struct MarkdownTokenEntitiesTests {
  private let h = MarkdownTestHarness()

  private func tokens(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
    h.parser.parse(input, language: h.language).tokens
  }

  private func pair(_ t: any CodeToken<MarkdownTokenElement>) -> (MarkdownTokenElement, String) {
    (t.element, t.text)
  }

  // 321: named entities across lines -> each should be a .href token
  @Test("Spec 321 (token): named entity references are tokenized as .href")
  func spec321_token() async throws {
    let input = "&nbsp; &amp; &copy; &AElig; &Dcaron;\n&frac34; &HilbertSpace; &DifferentialD;\n&ClockwiseContourIntegral; &ngE;\n"
    let toks = tokens(input)
    let expected: [(MarkdownTokenElement, String)] = [
      (.charref, "&nbsp;"), (.whitespaces, " "), (.charref, "&amp;"), (.whitespaces, " "),
      (.charref, "&copy;"), (.whitespaces, " "), (.charref, "&AElig;"), (.whitespaces, " "),
      (.charref, "&Dcaron;"), (.newline, "\n"),
      (.charref, "&frac34;"), (.whitespaces, " "), (.charref, "&HilbertSpace;"), (.whitespaces, " "),
      (.charref, "&DifferentialD;"), (.newline, "\n"),
      (.charref, "&ClockwiseContourIntegral;"), (.whitespaces, " "), (.charref, "&ngE;"),
      (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  // 322: decimal numeric references -> .href
  @Test("Spec 322 (token): decimal numeric references are .href")
  func spec322_token() async throws {
    let input = "&#35; &#1234; &#992; &#0;\n"
    let toks = tokens(input)
    let expected: [(MarkdownTokenElement, String)] = [
      (.charref, "&#35;"), (.whitespaces, " "), (.charref, "&#1234;"), (.whitespaces, " "),
      (.charref, "&#992;"), (.whitespaces, " "), (.charref, "&#0;"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  // 323: hex numeric references (x or X) -> .href
  @Test("Spec 323 (token): hexadecimal numeric references are .href")
  func spec323_token() async throws {
    let input = "&#X22; &#XD06; &#xcab;\n"
    let toks = tokens(input)
    let expected: [(MarkdownTokenElement, String)] = [
      (.charref, "&#X22;"), (.whitespaces, " "), (.charref, "&#XD06;"), (.whitespaces, " "),
      (.charref, "&#xcab;"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  // 324: malformed references -> not .href
  @Test("Spec 324 (token): malformed references are not .href")
  func spec324_token() async throws {
    let input = "&nbsp &x; &#; &#x;\n&#87654321;\n&#abcdef0;\n&ThisIsNotDefined; &hi?;\n"
    let toks = tokens(input)
    #expect(!toks.contains { $0.element == .charref && !$0.text.isEmpty })
    #expect(toks.last?.element == .eof)
  }

  // 325: unterminated named -> not .href
  @Test("Spec 325 (token): unterminated named stays literal, not .href")
  func spec325_token() async throws {
    let input = "&copy\n"
    let toks = tokens(input)
    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "&"), (.characters, "copy"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.count == expected.count)
    for i in 0..<expected.count { #expect(pair(toks[i]) == expected[i]) }
  }

  // 326: undefined named -> not .href
  @Test("Spec 326 (token): undefined named stays literal, not .href")
  func spec326_token() async throws {
    let input = "&MadeUpEntity;\n"
    let toks = tokens(input)
    let expectedTail: [(MarkdownTokenElement, String)] = [
      (.punctuation, "&"), (.characters, "MadeUpEntity"), (.punctuation, ";"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks.suffix(expectedTail.count).count == expectedTail.count)
    for (tok, exp) in zip(toks.suffix(expectedTail.count), expectedTail) { #expect(pair(tok) == exp) }
  }

  // 327: inside HTML tag attribute we still produce .href tokens for entities
  @Test("Spec 327 (token): entity inside HTML attribute is tokenized as .href")
  func spec327_token() async throws {
    let input = "<a href=\"&ouml;&ouml;.html\">\n"
    let toks = tokens(input)
    let hrefs = toks.filter { $0.element == .charref }.map { $0.text }
    #expect(hrefs == ["&ouml;", "&ouml;"])
  }

  // 328: entities in link destination and title -> .href tokens appear
  @Test("Spec 328 (token): entities in link dest/title produce .href tokens")
  func spec328_token() async throws {
    let input = "[foo](/f&ouml;&ouml; \"f&ouml;&ouml;\")\n"
    let toks = tokens(input)
    let hrefs = toks.filter { $0.element == .charref }.map { $0.text }
    #expect(hrefs == ["&ouml;", "&ouml;", "&ouml;", "&ouml;"])
  }

  // 329: reference-style link def with entities -> .href tokens in def
  @Test("Spec 329 (token): entities appear as .href in reference definitions too")
  func spec329_token() async throws {
    let input = "[foo]\n\n[foo]: /f&ouml;&ouml; \"f&ouml;&ouml;\"\n"
    let toks = tokens(input)
    let hrefs = toks.filter { $0.element == .charref }.map { $0.text }
    #expect(hrefs == ["&ouml;", "&ouml;", "&ouml;", "&ouml;"])
  }

  // 330: fenced code info string: .href recognized in info, but not in code body
  @Test("Spec 330 (token): .href recognized in info string, not inside code body")
  func spec330_token() async throws {
    let input = "``` f&ouml;&ouml;\nfoo &ouml;\n```\n"
    let toks = tokens(input)
    // two in info ("&ouml;&ouml;") and none in body because we are in code mode after newline
    let hrefs = toks.filter { $0.element == .charref }.map { $0.text }
    #expect(hrefs == ["&ouml;", "&ouml;"])
    // Ensure no .href appears after the first newline (i.e., inside the body)
    if let firstNL = toks.firstIndex(where: { $0.element == .newline }) {
      let after = toks.index(after: firstNL)
      #expect(!toks[after..<toks.endIndex].contains { $0.element == .charref })
    }
  }

  // 331: inline code preserves literal, so no .href inside code span
  @Test("Spec 331 (token): entities not recognized inside inline code")
  func spec331_token() async throws {
    let input = "`f&ouml;&ouml;`\n"
    let toks = tokens(input)
    #expect(!toks.contains { $0.element == .charref })
  }

  // 332: indented code block preserves literal, so no .href
  @Test("Spec 332 (token): entities not recognized inside indented code block")
  func spec332_token() async throws {
    let input = "    f&ouml;f&ouml;\n"
    let toks = tokens(input)
    #expect(!toks.contains { $0.element == .charref })
  }

  // 333: entity-escaped '*'
  @Test("Spec 333 (token): entity-escaped '*' tokenized as .href")
  func spec333_token() async throws {
    let input = "&#42;foo&#42;\n*foo*\n"
    let toks = tokens(input)
    let expectedFirstLine: [(MarkdownTokenElement, String)] = [
      (.charref, "&#42;"), (.characters, "foo"), (.charref, "&#42;"), (.newline, "\n")
    ]
    for i in 0..<expectedFirstLine.count { #expect(pair(toks[i]) == expectedFirstLine[i]) }
  }

  // 334: entity-escaped '*' not starting a list
  @Test("Spec 334 (token): line starting with '&#42;' begins with .href and space")
  func spec334_token() async throws {
    let input = "&#42; foo\n\n* foo\n"
    let toks = tokens(input)
    let expectedPrefix: [(MarkdownTokenElement, String)] = [
      (.charref, "&#42;"), (.whitespaces, " "), (.characters, "foo")
    ]
    #expect(toks.count > expectedPrefix.count)
    for i in 0..<expectedPrefix.count { #expect(pair(toks[i]) == expectedPrefix[i]) }
  }

  // 335: &#10; (LF) and 336: &#9; (tab) appear as .href tokens in the stream; tokenizer does not decode
  @Test("Spec 335-336 (token): numeric control refs tokenized as .href without decoding")
  func spec335_336_token() async throws {
    let toks1 = tokens("foo&#10;&#10;bar\n")
    let expected1: [(MarkdownTokenElement, String)] = [
      (.characters, "foo"), (.charref, "&#10;"), (.charref, "&#10;"), (.characters, "bar"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks1.count == expected1.count)
    for i in 0..<expected1.count { #expect(pair(toks1[i]) == expected1[i]) }

    let toks2 = tokens("&#9;foo\n")
    let expected2: [(MarkdownTokenElement, String)] = [
      (.charref, "&#9;"), (.characters, "foo"), (.newline, "\n"), (.eof, "")
    ]
    #expect(toks2.count == expected2.count)
    for i in 0..<expected2.count { #expect(pair(toks2[i]) == expected2[i]) }
  }

  // 337: &quot; in link title still appears as .href token at tokenizer stage
  @Test("Spec 337 (token): &quot; is tokenized as .href inside link title")
  func spec337_token() async throws {
    let toks = tokens("[a](url &quot;tit&quot;)\n")
    let hrefs = toks.filter { $0.element == .charref }.map { $0.text }
    #expect(hrefs == ["&quot;", "&quot;"])
  }
}

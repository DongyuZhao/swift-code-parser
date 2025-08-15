import Foundation
import Testing

@testable import CodeParserCollection

@Suite("CommonMark - Escaping when tokenizing")
struct MarkdownTokenEscapeTests {
  private let h = MarkdownTestHarness()
  @Test("Spec 308 - All punctuation should be escaped after a backslash")
  func spec308() async throws {
    let input =
      "\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.tokens.count == 3)
    #expect(result.tokens[0].element == .characters)
    #expect(result.tokens[0].text == "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
    #expect(result.tokens[1].element == .newline)
    #expect(result.tokens[1].text == "\n")
    #expect(result.tokens[2].element == .eof)
    #expect(result.tokens[2].text == "")
  }

  // Spec 309
  @Test(
    "Spec 309 - Backslash escapes neutralize punctuations across lines (token-level)"
  )
  func spec309() async throws {
    let input = "\\\t\\A\\a\\ \\3\\\u{03C6}\\\u{00AB}\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.characters, "\\"),
      (.whitespaces, "\t"),
      (.characters, "\\A\\a\\"),
      (.whitespaces, " "),
      (.characters, "\\3\\\u{03C6}\\\u{00AB}"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 310
  @Test("Spec 310 - Backslash escapes neutralize Markdown syntax across lines (token-level)")
  func spec310() async throws {
    let input = "\\*not emphasized*\n\\<br/> not a tag\n\\[not a link](/foo)\n\\`not code`\n1\\. not a list\n\\* not a list\n\\# not a heading\n\\[foo]: /url \"not a reference\"\n\\&ouml; not a character entity\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      // \*not emphasized*
      (.characters, "*not"), (.whitespaces, " "), (.characters, "emphasized"), (.punctuation, "*"),
      (.newline, "\n"),
      // \<br/> not a tag
      (.characters, "<br"), (.punctuation, "/"), (.punctuation, ">"), (.whitespaces, " "),
      (.characters, "not"), (.whitespaces, " "), (.characters, "a"), (.whitespaces, " "),
      (.characters, "tag"), (.newline, "\n"),
      // \[not a link](/foo)
      (.characters, "[not"), (.whitespaces, " "), (.characters, "a"), (.whitespaces, " "),
      (.characters, "link"),
      (.punctuation, "]"), (.punctuation, "("), (.punctuation, "/"), (.characters, "foo"),
      (.punctuation, ")"), (.newline, "\n"),
      // \`not code`
      (.characters, "`not"), (.whitespaces, " "), (.characters, "code"), (.punctuation, "`"),
      (.newline, "\n"),
      // 1\. not a list
      (.characters, "1."), (.whitespaces, " "), (.characters, "not"), (.whitespaces, " "),
      (.characters, "a"),
      (.whitespaces, " "), (.characters, "list"), (.newline, "\n"),
      // \* not a list
      (.characters, "*"), (.whitespaces, " "), (.characters, "not"), (.whitespaces, " "),
      (.characters, "a"),
      (.whitespaces, " "), (.characters, "list"), (.newline, "\n"),
      // \# not a heading
      (.characters, "#"), (.whitespaces, " "), (.characters, "not"), (.whitespaces, " "),
      (.characters, "a"),
      (.whitespaces, " "), (.characters, "heading"), (.newline, "\n"),
      // \[foo]: /url "not a reference"
      (.characters, "[foo"), (.punctuation, "]"), (.punctuation, ":"), (.whitespaces, " "),
      (.punctuation, "/"), (.characters, "url"),
      (.whitespaces, " "), (.punctuation, "\""),
      (.characters, "not"), (.whitespaces, " "), (.characters, "a"), (.whitespaces, " "),
      (.characters, "reference"),
      (.punctuation, "\""), (.newline, "\n"),
      // \&ouml; not a character entity
      (.characters, "&ouml"), (.punctuation, ";"), (.whitespaces, " "), (.characters, "not"),
      (.whitespaces, " "),
      (.characters, "a"), (.whitespaces, " "), (.characters, "character"), (.whitespaces, " "),
      (.characters, "entity"),
      (.newline, "\n"),
      // EOF
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 311
  @Test("Spec 311 - Escaped backslash will not neutralize next punctuation (token-level)")
  func spec311() async throws {
    let input = "\\\\*emphasis*\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.characters, "\\"),
      (.punctuation, "*"),
      (.characters, "emphasis"),
      (.punctuation, "*"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 312
  @Test(
    "Spec 312 - A backslash at the end of a line is treated as a line break (token-level)"
  )
  func spec312() async throws {
    let input = "foo\\\nbar\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.characters, "foo"),
      (.newline, "\n"),
      (.characters, "bar"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 313
  @Test("Spec 313 - Backslash escape will not work inside code spans")
  func spec313() async throws {
    let input = "`` \\[\\` ``\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.whitespaces, " "),
      (.characters, "\\[\\`"),
      (.whitespaces, " "),
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 314
  @Test("Spec 314 - Backslash escape will not work inside code blocks")
  func spec314() async throws {
    let input = "    \\[\\]\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.whitespaces, "    "),
      (.characters, "\\[\\]"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 315
  @Test("Spec 315 - Backslash escape will not work inside code blocks")
  func spec315() async throws {
    let input = "~~~\n\\[\\]\n~~~\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "~"),
      (.punctuation, "~"),
      (.punctuation, "~"),
      (.newline, "\n"),
      (.characters, "\\[\\]"),
      (.newline, "\n"),
      (.punctuation, "~"),
      (.punctuation, "~"),
      (.punctuation, "~"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 316
  @Test("Spec 316 - Backslash escape will not work inside autolinks")
  func spec316() async throws {
    let input = "<http://example.com?find=\\*>\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "<"),
      (.characters, "http"),
      (.punctuation, ":"),
      (.punctuation, "/"),
      (.punctuation, "/"),
      (.characters, "example"),
      (.punctuation, "."),
      (.characters, "com"),
      (.punctuation, "?"),
      (.characters, "find"),
      (.punctuation, "="),
      (.characters, "\\*"),
      (.punctuation, ">"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 317
  @Test("Spec 317 - Backslash escape will not work inside HTML")
  func spec317() async throws {
    let input = "<a href=\"/bar\\/)\">\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "<"),
      (.characters, "a"),
      (.whitespaces, " "),
      (.characters, "href"),
      (.punctuation, "="),
      (.punctuation, "\""),
      (.punctuation, "/"),
      (.characters, "bar\\/"),
      (.punctuation, ")"),
      (.punctuation, "\""),
      (.punctuation, ">"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 318
  @Test("Spec 318 - Backslash escape works inside url and link titles")
  func spec318() async throws {
    let input = "[foo](/bar\\* \"ti\\*tle\")\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "["),
      (.characters, "foo"),
      (.punctuation, "]"),
      (.punctuation, "("),
      (.punctuation, "/"),
      (.characters, "bar*"),
      (.whitespaces, " "),
      (.punctuation, "\""),
      (.characters, "ti*tle"),
      (.punctuation, "\""),
      (.punctuation, ")"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 319
  @Test("Spec 319 - Backslash escape works inside url and link titles")
  func spec319() async throws {
    let input = "[foo]\n\n[foo]: /bar\\* \"ti\\*tle\"\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "["),
      (.characters, "foo"),
      (.punctuation, "]"),
      (.newline, "\n"),
      (.newline, "\n"),
      (.punctuation, "["),
      (.characters, "foo"),
      (.punctuation, "]"),
      (.punctuation, ":"),
      (.whitespaces, " "),
      (.punctuation, "/"),
      (.characters, "bar*"),
      (.whitespaces, " "),
      (.punctuation, "\""),
      (.characters, "ti*tle"),
      (.punctuation, "\""),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }

  // Spec 320
  @Test("Spec 320 - Backslash escape works inside code block info string")
  func spec320() async throws {
    let input = "``` foo\\+bar\nfoo\n```\n"
    let result = h.parser.parse(input, language: h.language)

    let expected: [(MarkdownTokenElement, String)] = [
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.whitespaces, " "),
      (.characters, "foo+bar"),
      (.newline, "\n"),
      (.characters, "foo"),
      (.newline, "\n"),
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.punctuation, "`"),
      (.newline, "\n"),
      (.eof, ""),
    ]
    #expect(result.tokens.count == expected.count)
    for (i, (el, txt)) in expected.enumerated() {
      #expect(result.tokens[i].element == el)
      #expect(result.tokens[i].text == txt)
    }
  }
}

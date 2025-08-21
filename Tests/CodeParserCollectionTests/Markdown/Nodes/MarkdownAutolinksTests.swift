import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Autolinks Tests - Spec 035")
struct MarkdownAutolinksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Valid URI autolinks

  @Test("Valid URI autolink - basic HTTP URL")
  func basicHTTPAutolink() {
    let input = "<http://foo.bar.baz>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"http://foo.bar.baz\",title:\"\")[text(\"http://foo.bar.baz\")]]]")
  }

  @Test("Valid URI autolink - HTTP with query parameters and boolean flag")
  func httpAutolinkWithQueryParams() {
    let input = "<http://foo.bar.baz/test?q=hello&id=22&boolean>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"http://foo.bar.baz/test?q=hello&id=22&boolean\",title:\"\")[text(\"http://foo.bar.baz/test?q=hello&id=22&boolean\")]]]")
  }

  @Test("Valid URI autolink - IRC scheme with port and path")
  func ircAutolinkWithPort() {
    let input = "<irc://foo.bar:2233/baz>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"irc://foo.bar:2233/baz\",title:\"\")[text(\"irc://foo.bar:2233/baz\")]]]")
  }

  @Test("Valid URI autolink - uppercase scheme and email address")
  func uppercaseMailtoAutolink() {
    let input = "<MAILTO:FOO@BAR.BAZ>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"MAILTO:FOO@BAR.BAZ\",title:\"\")[text(\"MAILTO:FOO@BAR.BAZ\")]]]")
  }

  @Test("Valid URI autolink - custom scheme with plus and colon")
  func customSchemeWithPlusAutolink() {
    let input = "<a+b+c:d>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"a+b+c:d\",title:\"\")[text(\"a+b+c:d\")]]]")
  }

  @Test("Valid URI autolink - made-up scheme with special characters")
  func madeUpSchemeAutolink() {
    let input = "<made-up-scheme://foo,bar>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"made-up-scheme://foo,bar\",title:\"\")[text(\"made-up-scheme://foo,bar\")]]]")
  }

  @Test("Valid URI autolink - HTTP with relative path")
  func httpRelativePathAutolink() {
    let input = "<http://../>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"http://../\",title:\"\")[text(\"http://../\")]]]")
  }

  @Test("Valid URI autolink - localhost with port and path")
  func localhostWithPortAutolink() {
    let input = "<localhost:5001/foo>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"localhost:5001/foo\",title:\"\")[text(\"localhost:5001/foo\")]]]")
  }

  // MARK: - Invalid URI autolinks

  @Test("Invalid autolink - spaces not allowed")
  func autolinkWithSpaces() {
    let input = "<http://foo.bar/baz bim>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"<http://foo.bar/baz bim>\")]]")
  }

  @Test("URI autolink with backslash escapes - preserved in URL")
  func autolinkWithBackslashEscapes() {
    let input = "<http://example.com/\\[\\>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"http://example.com/%5C%5B%5C\",title:\"\")[text(\"http://example.com/\\[\\>\")]]]")
  }

  // MARK: - Email autolinks

  @Test("Valid email autolink - basic email address")
  func basicEmailAutolink() {
    let input = "<foo@bar.example.com>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"mailto:foo@bar.example.com\",title:\"\")[text(\"foo@bar.example.com\")]]]")
  }

  @Test("Valid email autolink - email with special characters")
  func emailAutolinkWithSpecialChars() {
    let input = "<foo+special@Bar.baz-bar0.com>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"mailto:foo+special@Bar.baz-bar0.com\",title:\"\")[text(\"foo+special@Bar.baz-bar0.com\")]]]")
  }

  // MARK: - Invalid email autolinks

  @Test("Invalid email autolink - backslash escapes not allowed")
  func emailAutolinkWithBackslash() {
    let input = "<foo\\+@bar.example.com>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"<foo\\\\+@bar.example.com>\")]]")
  }

  // MARK: - Not autolinks

  @Test("Not an autolink - empty angle brackets")
  func emptyAngleBrackets() {
    let input = "<>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"<>\")]]")
  }

  @Test("Not an autolink - spaces around URL")
  func spacesAroundURL() {
    let input = "< http://foo.bar >"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"< http://foo.bar >\")]]")
  }

  @Test("Not an autolink - scheme too short")
  func schemeTooShort() {
    let input = "<m:abc>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"<m:abc>\")]]")
  }

  // These test cases are CommonMark but has been overrided by GFM.
  // @Test("Not an autolink - no scheme")
  // func noScheme() {
  //   let input = "<foo.bar.baz>"
  //   let result = parser.parse(input, language: language)
  //
  //   #expect(sig(result.root) == "document[paragraph[text(\"<foo.bar.baz>\")]]")
  // }

  // @Test("Not an autolink - bare URL without angle brackets")
  // func bareURLWithoutBrackets() {
  //   let input = "http://example.com"
  //   let result = parser.parse(input, language: language)
  //
  //   #expect(sig(result.root) == "document[paragraph[text(\"http://example.com\")]]")
  // }

  // @Test("Not an autolink - bare email without angle brackets")
  // func bareEmailWithoutBrackets() {
  //   let input = "foo@bar.example.com"
  //   let result = parser.parse(input, language: language)
  //
  //   #expect(sig(result.root) == "document[paragraph[text(\"foo@bar.example.com\")]]")
  // }
}

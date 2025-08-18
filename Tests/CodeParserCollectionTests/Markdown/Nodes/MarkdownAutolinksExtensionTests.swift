import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Autolinks Extension Tests - Spec 036")
struct MarkdownAutolinksExtensionTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Extended WWW autolinks

  @Test("WWW autolink with valid domain automatically inserts http scheme")
  func basicWWWAutolink() {
    let input = "www.commonmark.org"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://www.commonmark.org\",title:\"\")[text(\"www.commonmark.org\")]]]")
  }

  @Test("WWW autolink includes non-space non-< characters after valid domain")
  func wwwAutolinkWithPath() {
    let input = "Visit www.commonmark.org/help for more information."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org/help\",title:\"\")[text(\"www.commonmark.org/help\")],text(\" for more information.\")]]")
  }

  @Test("WWW autolink path validation excludes trailing punctuation")
  func wwwAutolinkTrailingPunctuation() {
    let input = "Visit www.commonmark.org.\n\nVisit www.commonmark.org/a.b."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org\",title:\"\")[text(\"www.commonmark.org\")],text(\".\")]],paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org/a.b\",title:\"\")[text(\"www.commonmark.org/a.b\")],text(\".\")]]")
  }

  @Test("WWW autolink excludes unmatched trailing parentheses based on balance count")
  func wwwAutolinkParenthesesBalancing() {
    let input = "www.google.com/search?q=Markup+(business)\n\nwww.google.com/search?q=Markup+(business)))\n\n(www.google.com/search?q=Markup+(business))\n\n(www.google.com/search?q=Markup+(business)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")]],paragraph[link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")],text(\"))\")],paragraph[text(\"(\"),link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")],text(\")\")],paragraph[text(\"(\"),link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")]]")
  }

  @Test("WWW autolink with interior parentheses only applies no special rules")
  func wwwAutolinkInteriorParentheses() {
    let input = "www.google.com/search?q=(business))+ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://www.google.com/search?q=(business))+ok\",title:\"\")[text(\"www.google.com/search?q=(business))+ok\")]]]")
  }

  @Test("WWW autolink excludes semicolon if it resembles entity reference")
  func wwwAutolinkSemicolonHandling() {
    let input = "www.google.com/search?q=commonmark&hl=en\n\nwww.google.com/search?q=commonmark&hl;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://www.google.com/search?q=commonmark&hl=en\",title:\"\")[text(\"www.google.com/search?q=commonmark&hl=en\")]],paragraph[link(url:\"http://www.google.com/search?q=commonmark\",title:\"\")[text(\"www.google.com/search?q=commonmark\")],text(\"&hl;\")]]")
  }

  @Test("WWW autolink terminates immediately when encountering less-than symbol")
  func wwwAutolinkLessThanTermination() {
    let input = "www.commonmark.org/he<lp"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://www.commonmark.org/he\",title:\"\")[text(\"www.commonmark.org/he\")],text(\"<lp\")]]")
  }

  // MARK: - Extended URL autolinks

  @Test("URL autolink recognizes http, https, ftp schemes with valid domain")
  func extendedURLAutolinks() {
    let input = "http://commonmark.org\n\n(Visit https://encrypted.google.com/search?q=Markup+(business))\n\nAnonymous FTP is available at ftp://foo.bar.baz."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"http://commonmark.org\",title:\"\")[text(\"http://commonmark.org\")]],paragraph[text(\"(Visit \"),link(url:\"https://encrypted.google.com/search?q=Markup+(business)\",title:\"\")[text(\"https://encrypted.google.com/search?q=Markup+(business)\")],text(\")\")],paragraph[text(\"Anonymous FTP is available at \"),link(url:\"ftp://foo.bar.baz\",title:\"\")[text(\"ftp://foo.bar.baz\")],text(\".\")]]")
  }

  // MARK: - Extended email autolinks

  @Test("Email autolink with valid format automatically adds mailto scheme")
  func basicEmailAutolink() {
    let input = "foo@bar.baz"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"mailto:foo@bar.baz\",title:\"\")[text(\"foo@bar.baz\")]]]")
  }

  @Test("Email autolink allows plus before @ but not after")
  func emailAutolinkPlusValidation() {
    let input = "hello@mail+xyz.example isn't valid, but hello+xyz@mail.example is."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"hello@mail+xyz.example isn't valid, but \"),link(url:\"mailto:hello+xyz@mail.example\",title:\"\")[text(\"hello+xyz@mail.example\")],text(\" is.\")]]")
  }

  @Test("Email autolink allows dot/dash/underscore on both sides of @ but only dot at end")
  func emailAutolinkSpecialCharacters() {
    let input = "a.b-c_d@a.b\n\na.b-c_d@a.b.\n\na.b-c_d@a.b-\n\na.b-c_d@a.b_"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"mailto:a.b-c_d@a.b\",title:\"\")[text(\"a.b-c_d@a.b\")]],paragraph[link(url:\"mailto:a.b-c_d@a.b\",title:\"\")[text(\"a.b-c_d@a.b\")],text(\".\")],paragraph[text(\"a.b-c_d@a.b-\")],paragraph[text(\"a.b-c_d@a.b_\")]]")
  }
}

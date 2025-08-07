import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Tokenizer HTML Tests")
struct MarkdownCodeTokenizerHTMLTests {
  private func tokenize(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
    let language = MarkdownLanguage()
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize(input)
    return tokens
  }

  @Test("HTML tag variations")
  func htmlTagVariations() {
    let cases: [(String, MarkdownTokenElement)] = [
      ("<p>", .htmlUnclosedBlock),
      ("<div>", .htmlUnclosedBlock),
      ("<span>", .htmlUnclosedBlock),
      ("<br />", .htmlTag),
      ("<hr />", .htmlTag),
      ("</p>", .htmlTag),
      ("</div>", .htmlTag),
      ("</span>", .htmlTag),
    ]
    for (text, expected) in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == expected)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("HTML entities")
  func htmlEntities() {
    let cases: [(String, MarkdownTokenElement)] = [
      ("&amp;", .htmlEntity),
      ("&lt;", .htmlEntity),
      ("&gt;", .htmlEntity),
      ("&quot;", .htmlEntity),
      ("&nbsp;", .htmlEntity),
      ("&copy;", .htmlEntity),
    ]
    for (text, expected) in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == expected)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("HTML comments")
  func htmlComments() {
    let cases: [String] = [
      "<!-- Simple comment -->",
      "<!--Multiple\nlines\ncomment-->",
      "<!-- Comment with &entities; -->",
    ]
    for text in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == .htmlComment)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("HTML block elements")
  func htmlBlockElements() {
    let cases: [String] = [
      "<div>content</div>",
      "<p>paragraph</p>",
      "<strong>bold</strong>",
      "<em>italic</em>",
      "<code>code</code>",
    ]
    for text in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == .htmlBlock)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("Mixed HTML and Markdown")
  func mixedHtmlAndMarkdown() {
    let text = "Text with <strong>bold</strong> and *emphasis*"
    let tokens = tokenize(text)
    let expected: [MarkdownTokenElement] = [
      .text, .space, .text, .space, .htmlBlock, .space, .text, .space, .asterisk, .text, .asterisk,
      .eof,
    ]
    #expect(tokens.map { $0.element } == expected)
  }

  @Test("Invalid HTML-like content")
  func invalidHtmlLikeContent() {
    let text = "< not a tag > and < another"
    let tokens = tokenize(text)
    let expected: [MarkdownTokenElement] = [
      .lt, .space, .text, .space, .text, .space, .text, .space, .gt, .space, .text, .space, .lt,
      .space, .text, .eof,
    ]
    #expect(tokens.map { $0.element } == expected)
  }
}

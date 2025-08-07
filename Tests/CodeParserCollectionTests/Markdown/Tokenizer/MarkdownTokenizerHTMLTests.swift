import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tokenizer HTML Tests")
struct MarkdownTokenizerHTMLTests {

  private var tokenizer: CodeTokenizer<MarkdownTokenElement> {
    let language = MarkdownLanguage()
    return CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
  }

  // MARK: - Helper Methods

  /// Helper to assert token properties
  private func assertToken(
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    expectedElement: MarkdownTokenElement,
    expectedText: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    guard index < tokens.count else {
      Issue.record(
        "Index \(index) out of bounds for tokens array with count \(tokens.count)",
        sourceLocation: sourceLocation)
      return
    }

    let token = tokens[index]
    #expect(
      token.element == expectedElement, "Token element mismatch at index \(index)",
      sourceLocation: sourceLocation)
    #expect(
      token.text == expectedText, "Token text mismatch at index \(index)",
      sourceLocation: sourceLocation)
  }

  // MARK: - HTML Tag Tests

  @Test("HTML tag variations")
  func htmlTagVariations() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("<p>", .htmlUnclosedBlock),
      ("<div>", .htmlUnclosedBlock),
      ("<span>", .htmlUnclosedBlock),
      ("<br />", .htmlTag),
      ("<hr />", .htmlTag),
      ("</p>", .htmlTag),
      ("</div>", .htmlTag),
      ("</span>", .htmlTag),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for HTML tag '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("HTML entities")
  func htmlEntities() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("&amp;", .htmlEntity),
      ("&lt;", .htmlEntity),
      ("&gt;", .htmlEntity),
      ("&quot;", .htmlEntity),
      ("&nbsp;", .htmlEntity),
      ("&copy;", .htmlEntity),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for HTML entity '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("HTML comments")
  func htmlComments() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("<!-- Simple comment -->", .htmlComment),
      ("<!--Multiple\nlines\ncomment-->", .htmlComment),
      ("<!-- Comment with &entities; -->", .htmlComment),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for HTML comment '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("HTML block elements")
  func htmlBlockElements() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("<div>content</div>", .htmlBlock),
      ("<p>paragraph</p>", .htmlBlock),
      ("<strong>bold</strong>", .htmlBlock),
      ("<em>italic</em>", .htmlBlock),
      ("<code>code</code>", .htmlBlock),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for HTML block '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("Mixed HTML and Markdown")
  func mixedHtmlAndMarkdown() {
    let text = "Text with <strong>bold</strong> and *emphasis*"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .text, .space, .text, .space, .htmlBlock, .space, .text, .space, .asterisk, .text, .asterisk,
      .eof,
    ]

    #expect(tokens.count == expectedElements.count)
    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("Invalid HTML-like content")
  func invalidHtmlLikeContent() {
    let text = "< not a tag > and < another"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .lt, .space, .text, .space, .text, .space, .text, .space, .gt, .space, .text, .space, .lt,
      .space, .text, .eof,
    ]

    #expect(tokens.count == expectedElements.count)
    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }
}

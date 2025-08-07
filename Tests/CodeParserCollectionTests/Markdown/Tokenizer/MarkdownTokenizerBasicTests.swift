import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tokenizer Basic Tests")
struct MarkdownTokenizerBasicTests {

  private let tokenizer: CodeTokenizer<MarkdownTokenElement>

  init() {
    let language = MarkdownLanguage()
    tokenizer = CodeTokenizer(
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

  /// Helper to get token elements as array
  private func getTokenElements(_ tokens: [any CodeToken<MarkdownTokenElement>])
    -> [MarkdownTokenElement]
  {
    return tokens.map { $0.element }
  }

  /// Helper to get token texts as array
  private func getTokenTexts(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [String] {
    return tokens.map { $0.text }
  }

  /// Helper to print tokens for debugging
  private func printTokens(_ tokens: [any CodeToken<MarkdownTokenElement>], input: String) {
    print("Input: '\(input)'")
    print("Number of tokens: \(tokens.count)")
    for (index, token) in tokens.enumerated() {
      print("Token \(index): \(token.element) - '\(token.text)'")
    }
  }

  // MARK: - Basic Token Tests

  @Test("Single character tokens")
  func singleCharacterTokens() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("#", .hash),
      ("*", .asterisk),
      ("_", .underscore),
      ("`", .text),
      ("-", .dash),
      ("+", .plus),
      ("=", .equals),
      ("~", .tilde),
      ("|", .pipe),
      (":", .colon),
      ("!", .exclamation),
      ("$", .text),  // Dollar sign treated as text
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for input '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("Paired tokens")
  func pairedTokens() {
    let testCases: [(String, [MarkdownTokenElement])] = [
      ("[]", [.leftBracket, .rightBracket]),
      ("()", [.leftParen, .rightParen]),
      ("{}", [.leftBrace, .rightBrace]),
      ("<>", [.lt, .gt]),
    ]

    for (input, expectedElements) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(
        tokens.count == expectedElements.count + 1,
        "Expected \(expectedElements.count + 1) tokens for input '\(input)'")

      for (index, expectedElement) in expectedElements.enumerated() {
        assertToken(
          at: index, in: tokens, expectedElement: expectedElement,
          expectedText: String(input[input.index(input.startIndex, offsetBy: index)]))
      }
      assertToken(at: expectedElements.count, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  // MARK: - Whitespace Tests

  @Test("Whitespace tokens")
  func whitespaceTokens() {
    let testCases: [(String, MarkdownTokenElement)] = [
      (" ", .space),
      ("\t", .tab),
      ("\n", .newline),
      ("\r", .carriageReturn),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for whitespace input")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("CRLF handling")
  func crlfHandling() {
    let text = "\r\n"
    let (tokens, _) = tokenizer.tokenize(text)

    #expect(tokens.count == 2)
    #expect(tokens[0].element == .newline)
    #expect(tokens[0].text == "\r\n")
    #expect(tokens[1].element == .eof)
  }

  @Test("Multiple whitespace")
  func multipleWhitespace() {
    let text = "   \t\n  "
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .space, .space, .space, .tab, .newline, .space, .space, .eof,
    ]

    #expect(tokens.count == expectedElements.count)
    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  // MARK: - Text and Number Tests

  @Test("Text tokens")
  func textTokens() {
    let testCases: [(String, MarkdownTokenElement)] = [
      ("a", .text),
      ("hello", .text),
      ("café", .text),
      ("🚀", .text),
      ("中文", .text),
      ("abc123", .text),
      ("123abc", .text),
    ]

    for (input, expectedElement) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for input '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("Number tokens")
  func numberTokens() {
    let testCases = ["123", "456", "789"]

    for input in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == 2, "Expected 2 tokens for number input '\(input)'")
      assertToken(at: 0, in: tokens, expectedElement: .number, expectedText: input)
      assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
    }
  }

  @Test("Mixed alphanumeric tokens")
  func mixedAlphanumericTokens() {
    let text = "abc-123"
    let (tokens, _) = tokenizer.tokenize(text)

    #expect(tokens.count == 4)  // "abc" + "-" + "123" + eof
    assertToken(at: 0, in: tokens, expectedElement: .text, expectedText: "abc")
    assertToken(at: 1, in: tokens, expectedElement: .dash, expectedText: "-")
    assertToken(at: 2, in: tokens, expectedElement: .number, expectedText: "123")
    assertToken(at: 3, in: tokens, expectedElement: .eof, expectedText: "")
  }

  // MARK: - Basic Markdown Syntax Tests

  @Test("Markdown headings")
  func markdownHeadings() {
    let text = "# Hello"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [.hash, .space, .text, .eof]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("Markdown links")
  func markdownLinks() {
    let text = "[link](url)"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof,
    ]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("Markdown images")
  func markdownImages() {
    let text = "![alt](src)"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .exclamation, .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof,
    ]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("Markdown emphasis")
  func markdownEmphasis() {
    let testCases: [(String, [MarkdownTokenElement])] = [
      ("*italic*", [.asterisk, .text, .asterisk, .eof]),
      ("**bold**", [.asterisk, .asterisk, .text, .asterisk, .asterisk, .eof]),
      ("_underline_", [.underscore, .text, .underscore, .eof]),
    ]

    for (input, expectedElements) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == expectedElements.count, "Failed for input '\(input)'")

      for (index, expectedElement) in expectedElements.enumerated() {
        #expect(
          tokens[index].element == expectedElement,
          "Token \(index) element mismatch for input '\(input)'")
      }
    }
  }

  @Test("Markdown code")
  func markdownCode() {
    let text = "`code`"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [.inlineCode, .eof]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }

    // Check the full text of the inline code token
    #expect(tokens[0].text == "`code`", "Inline code token should contain the full text")
  }

  @Test("Markdown blockquote")
  func markdownBlockquote() {
    let text = "> Quote"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [.gt, .space, .text, .eof]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("Markdown lists")
  func markdownLists() {
    let testCases: [(String, [MarkdownTokenElement])] = [
      ("- Item", [.dash, .space, .text, .eof]),
      ("+ Item", [.plus, .space, .text, .eof]),
      ("1. Item", [.number, .dot, .space, .text, .eof]),
    ]

    for (input, expectedElements) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == expectedElements.count, "Failed for input '\(input)'")

      for (index, expectedElement) in expectedElements.enumerated() {
        #expect(
          tokens[index].element == expectedElement,
          "Token \(index) element mismatch for input '\(input)'")
      }
    }
  }

  // MARK: - GitHub Flavored Markdown Tests

  @Test("GFM table")
  func gfmTable() {
    let text = "| A | B |"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .pipe, .space, .text, .space, .pipe, .space, .text, .space, .pipe, .eof,
    ]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("GFM strikethrough")
  func gfmStrikethrough() {
    let text = "~~strike~~"
    let (tokens, _) = tokenizer.tokenize(text)

    let expectedElements: [MarkdownTokenElement] = [
      .tilde, .tilde, .text, .tilde, .tilde, .eof,
    ]
    #expect(tokens.count == expectedElements.count)

    for (index, expectedElement) in expectedElements.enumerated() {
      #expect(tokens[index].element == expectedElement, "Token \(index) element mismatch")
    }
  }

  @Test("GFM task lists")
  func gfmTaskLists() {
    let testCases: [(String, [MarkdownTokenElement])] = [
      ("- [ ] Task", [.dash, .space, .leftBracket, .space, .rightBracket, .space, .text, .eof]),
      ("- [x] Done", [.dash, .space, .leftBracket, .text, .rightBracket, .space, .text, .eof]),
    ]

    for (input, expectedElements) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == expectedElements.count, "Failed for input '\(input)'")

      for (index, expectedElement) in expectedElements.enumerated() {
        #expect(
          tokens[index].element == expectedElement,
          "Token \(index) element mismatch for input '\(input)'")
      }
    }
  }

  // MARK: - Code Block and Inline Code Tests

  @Test("Inline code tokenization")
  func inlineCodeTokenization() {
    let testCases: [(String, String)] = [
      ("`code`", "`code`"),
      ("`let x = 1`", "`let x = 1`"),
      ("`code with spaces`", "`code with spaces`"),
      ("`code`with`text`", "`code`"),  // Should only capture the first inline code
    ]

    for (input, expectedText) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count > 0, "Should have at least one token for input: \(input)")

      let firstToken = tokens[0]
      #expect(
        firstToken.element == .inlineCode, "First token should be inline code for input: \(input)")
      #expect(
        firstToken.text == expectedText, "Token text should match expected for input: \(input)")
    }
  }

  @Test("Code block tokenization")
  func codeBlockTokenization() {
    let testCases: [(String, String)] = [
      ("```\ncode\n```", "```\ncode\n```"),
      ("```swift\nlet x = 1\n```", "```swift\nlet x = 1\n```"),
      (
        "```\nfunction test() {\n  return 42;\n}\n```",
        "```\nfunction test() {\n  return 42;\n}\n```"
      ),
      ("```python\nprint('hello')\n```", "```python\nprint('hello')\n```"),
    ]

    for (input, expectedText) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count > 0, "Should have at least one token for input: \(input)")

      let firstToken = tokens[0]
      #expect(
        firstToken.element == .fencedCodeBlock,
        "First token should be fenced code block for input: \(input)")
      #expect(
        firstToken.text == expectedText, "Token text should match expected for input: \(input)")
    }
  }

  @Test("Indented code block tokenization")
  func indentedCodeBlockTokenization() {
    let testCases: [(String, String)] = [
      ("    code line 1\n    code line 2", "    code line 1\n    code line 2"),
      ("\tcode with tab", "\tcode with tab"),
      ("    let x = 42\n    print(x)", "    let x = 42\n    print(x)"),
    ]

    for (input, expectedText) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count > 0, "Should have at least one token for input: \(input)")

      let firstToken = tokens[0]
      #expect(
        firstToken.element == .indentedCodeBlock,
        "First token should be indented code block for input: \(input)")
      #expect(
        firstToken.text == expectedText, "Token text should match expected for input: \(input)")
    }
  }

  @Test("Unclosed code block")
  func unclosedCodeBlock() {
    let input = "```\ncode without closing"
    let (tokens, _) = tokenizer.tokenize(input)

    #expect(tokens.count > 0, "Should have at least one token")

    let firstToken = tokens[0]
    #expect(firstToken.element == .fencedCodeBlock, "Should be treated as fenced code block")
    #expect(firstToken.text == input, "Should capture all text until EOF")
  }

  @Test("Unclosed inline code")
  func unclosedInlineCode() {
    let input = "`code without closing"
    let (tokens, _) = tokenizer.tokenize(input)

    // Should fall back to individual backtick token
    #expect(tokens.count > 0, "Should have at least one token")

    let firstToken = tokens[0]
    #expect(firstToken.element == .text, "Should be treated as backtick when unclosed")
    #expect(firstToken.text == "`", "Should be just the backtick")
  }

  @Test("Custom container tokenization")
  func customContainerTokenization() {
    let input = "::: custom\ncontent\n:::"
    let (tokens, _) = tokenizer.tokenize(input)

    #expect(tokens.count == 2)
    #expect(tokens[0].element == .customContainer)
    #expect(tokens[0].text == input)
    #expect(tokens[1].element == .eof)
  }

  // MARK: - Edge Cases and Special Scenarios

  @Test("Empty and whitespace inputs")
  func emptyAndWhitespaceInputs() {
    let testCases: [(String, Int)] = [
      ("", 1),  // EOF only
      ("   ", 4),  // 3 spaces + EOF
      ("   \t\n  ", 8),  // 3 spaces + tab + newline + 2 spaces + EOF
    ]

    for (input, expectedCount) in testCases {
      let (tokens, _) = tokenizer.tokenize(input)
      #expect(tokens.count == expectedCount, "Failed for input '\(input)'")
      #expect(tokens.last?.element == .eof, "Should end with EOF")
    }
  }

  @Test("Special characters")
  func specialCharacters() {
    let text = "!@#$%^&*()_+-=[]{}|;:'\",.<>?/~`"
    let (tokens, _) = tokenizer.tokenize(text)

    // Should tokenize each character individually and end with EOF
    #expect(tokens.count == 32)  // 31 chars + EOF
    #expect(tokens.last?.element == .eof)

    // Test some key characters are properly recognized
    #expect(tokens[0].element == .exclamation)
    #expect(tokens[1].element == .atSign)
    #expect(tokens[2].element == .hash)
    #expect(tokens[5].element == .caret)
    #expect(tokens[6].element == .ampersand)
    #expect(tokens[7].element == .asterisk)
  }

  @Test("Unicode characters")
  func unicodeCharacters() {
    let text = "café 🚀 中文"
    let (tokens, _) = tokenizer.tokenize(text)

    #expect(tokens.count > 1, "Should produce multiple tokens")
    #expect(tokens.last?.element == .eof, "Should end with EOF")
  }

  @Test("Token ranges")
  func tokenRanges() {
    let text = "abc"
    let (tokens, _) = tokenizer.tokenize(text)

    #expect(tokens.count == 2)  // "abc" + EOF
    #expect(tokens[0].range == text.startIndex..<text.endIndex)
    #expect(tokens[1].range == text.endIndex..<text.endIndex)  // EOF range
  }

  // MARK: - Token Utilities Tests

  @Test("Token utilities")
  func tokenUtilities() {
    let text = "* _test_ `code` \n"
    let (tokens, _) = tokenizer.tokenize(text)

    // Test asterisk token properties
    guard let asteriskTokenBase = tokens.first(where: { $0.element == .asterisk }),
      let asteriskToken = asteriskTokenBase as? MarkdownToken
    else {
      Issue.record("Expected to find asterisk token")
      return
    }

    #expect(asteriskToken.isEmphasisDelimiter)
    #expect(!asteriskToken.isWhitespace)
    #expect(asteriskToken.canStartBlock)
    #expect(!asteriskToken.isMathDelimiter)
    #expect(!asteriskToken.isTableDelimiter)

    // Test underscore token properties
    guard let underscoreTokenBase = tokens.first(where: { $0.element == .underscore }),
      let underscoreToken = underscoreTokenBase as? MarkdownToken
    else {
      Issue.record("Expected to find underscore token")
      return
    }

    #expect(underscoreToken.isEmphasisDelimiter)
    #expect(!underscoreToken.isWhitespace)

    // Test space token properties
    guard let spaceTokenBase = tokens.first(where: { $0.element == .space }),
      let spaceToken = spaceTokenBase as? MarkdownToken
    else {
      Issue.record("Expected to find space token")
      return
    }

    #expect(!spaceToken.isEmphasisDelimiter)
    #expect(spaceToken.isWhitespace)
    #expect(!spaceToken.isLineEnding)

    // Test newline token properties
    guard let newlineTokenBase = tokens.first(where: { $0.element == .newline }),
      let newlineToken = newlineTokenBase as? MarkdownToken
    else {
      Issue.record("Expected to find newline token")
      return
    }

    #expect(newlineToken.isWhitespace)
    #expect(newlineToken.isLineEnding)

    // Test inline code token properties
    guard let inlineCodeTokenBase = tokens.first(where: { $0.element == .inlineCode }),
      let inlineCodeToken = inlineCodeTokenBase as? MarkdownToken
    else {
      Issue.record("Expected to find inline code token")
      return
    }

    #expect(!inlineCodeToken.isEmphasisDelimiter)
    #expect(!inlineCodeToken.isWhitespace)
    #expect(inlineCodeToken.canStartBlock)
    #expect(!inlineCodeToken.isMathDelimiter)
    #expect(!inlineCodeToken.isTableDelimiter)
  }
}

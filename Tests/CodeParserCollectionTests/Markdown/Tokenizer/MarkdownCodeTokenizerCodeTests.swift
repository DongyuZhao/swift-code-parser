import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Tokenizer Code Tests")
struct MarkdownCodeTokenizerCodeTests {
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

  @Test("Inline code")
  func inlineCode() {
    let cases: [(String, String)] = [
      ("`code`", "`code`"),
      ("`let x = 1`", "`let x = 1`"),
      ("`code with spaces`", "`code with spaces`"),
      ("`code`with`text`", "`code`"),
    ]
    for (input, expectedText) in cases {
      let tokens = tokenize(input)
      #expect(tokens.first?.element == .inlineCode)
      #expect((tokens.first as? MarkdownToken)?.text == expectedText)
      #expect(tokens.last?.element == .eof)
    }
  }

  @Test("Fenced code blocks")
  func fencedCodeBlocks() {
    let cases: [String] = [
      "```\ncode\n```",
      "```swift\nlet x = 1\n```",
      "```\nfunction test() {\n  return 42;\n}\n```",
      "```python\nprint('hello')\n```",
    ]
    for input in cases {
      let tokens = tokenize(input)
      #expect(tokens.first?.element == .fencedCodeBlock)
      #expect((tokens.first as? MarkdownToken)?.text == input)
      #expect(tokens.last?.element == .eof)
    }
  }

  @Test("Indented code blocks")
  func indentedCodeBlocks() {
    let cases: [String] = [
      "    code line 1\n    code line 2",
      "\tcode with tab",
      "    let x = 42\n    print(x)",
    ]
    for input in cases {
      let tokens = tokenize(input)
      #expect(tokens.first?.element == .indentedCodeBlock)
      #expect((tokens.first as? MarkdownToken)?.text == input)
      #expect(tokens.last?.element == .eof)
    }
  }

  @Test("Unclosed fenced code block")
  func unclosedFencedCodeBlock() {
    let input = "```\ncode without closing"
    let tokens = tokenize(input)
    #expect(tokens.first?.element == .fencedCodeBlock)
    #expect((tokens.first as? MarkdownToken)?.text == input)
    #expect(tokens.last?.element == .eof)
  }

  @Test("Unclosed inline code")
  func unclosedInlineCode() {
    let input = "`code without closing"
    let tokens = tokenize(input)
    #expect(tokens.first?.element == .text)
    #expect((tokens.first as? MarkdownToken)?.text == "`")
    #expect(tokens.last?.element == .eof)
  }
}

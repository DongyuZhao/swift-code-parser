import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Tokenizer Basic Tests")
struct MarkdownCodeTokenizerBasicTests {
  @Test("Heading tokenization")
  func headingTokenization() {
    let language = MarkdownLanguage()
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize("# Title")
    #expect(tokens.count == 4)
    #expect(tokens[0].element == .hash)
    #expect(tokens[1].element == .space)
    #expect(tokens[2].element == .text)
    #expect(tokens[3].element == .eof)
  }

  @Test("Autolink tokenization")
  func autolinkTokenization() {
    let language = MarkdownLanguage()
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize("<https://example.com>")
    #expect(tokens.count == 2)
    #expect(tokens[0].element == .autolink)
    #expect(tokens[0].text == "<https://example.com>")
    #expect(tokens[1].element == .eof)
  }

  @Test("Bare URL tokenization")
  func bareURLTokenization() {
    let language = MarkdownLanguage()
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize("https://example.com")
    #expect(tokens.count == 2)
    #expect(tokens[0].element == .url)
    #expect(tokens[1].element == .eof)
  }

  @Test("Bare email tokenization")
  func bareEmailTokenization() {
    let language = MarkdownLanguage()
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { language.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize("user@example.com")
    #expect(tokens.count == 2)
    #expect(tokens[0].element == .email)
    #expect(tokens[1].element == .eof)
  }
}

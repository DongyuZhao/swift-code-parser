import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Tokenizer Custom Container Tests")
struct MarkdownCodeTokenizerCustomContainerTests {
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

  @Test("Custom container tokenization")
  func customContainerTokenization() {
    let input = "::: custom\ncontent\n:::"
    let tokens = tokenize(input)
    #expect(tokens.count == 2)
    #expect(tokens[0].element == .customContainer)
    #expect((tokens[0] as? MarkdownToken)?.text == input)
    #expect(tokens[1].element == .eof)
  }

  @Test("Unclosed custom container")
  func unclosedCustomContainer() {
    let input = "::: name\ntext"
    let tokens = tokenize(input)
    #expect(tokens.count == 2)
    #expect(tokens[0].element == .customContainer)
    #expect((tokens[0] as? MarkdownToken)?.text == input)
    #expect(tokens[1].element == .eof)
  }
}

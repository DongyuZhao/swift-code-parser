import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Tokenizer Formula Tests")
struct MarkdownCodeTokenizerFormulaTests {
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

  @Test("Dollar formulas")
  func dollarFormulas() {
    let cases: [(String, MarkdownTokenElement)] = [
      ("$math$", .formula),
      ("$$display$$", .formulaBlock),
    ]
    for (text, expected) in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == expected)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("TeX formulas")
  func texFormulas() {
    let cases: [(String, MarkdownTokenElement)] = [
      ("\\(x\\)", .formula),
      ("\\[x\\]", .formulaBlock),
    ]
    for (text, expected) in cases {
      let tokens = tokenize(text)
      #expect(tokens.count == 2)
      #expect(tokens[0].element == expected)
      #expect(tokens[0].text == text)
      #expect(tokens[1].element == .eof)
    }
  }

  @Test("Inline formula in text")
  func inlineFormulaInText() {
    let input = "Equation $x = y$ inside"
    let tokens = tokenize(input)
    #expect(tokens.contains { $0.element == .formula })
    #expect(tokens.last?.element == .eof)
  }

  @Test("Invalid inline formula with whitespace")
  func invalidInlineFormulaWithWhitespace() {
    let input = "$ x = y$"
    let tokens = tokenize(input)
    let elements = tokens.map { $0.element }
    #expect(!elements.contains(.formula))
    #expect(elements.contains(.text))
    #expect(tokens.last?.element == .eof)
  }
}

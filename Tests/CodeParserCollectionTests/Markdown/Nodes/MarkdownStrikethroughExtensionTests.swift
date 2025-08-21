import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Strikethrough Extension Tests - Spec 032")
struct MarkdownStrikethroughExtensionTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Basic strikethrough functionality

  @Test("Basic strikethrough with tildes wrapping text")
  func basicStrikethroughWithTildes() {
    let input = "~~Hi~~ Hello, world!"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strike[text(\"Hi\")],text(\" Hello, world!\")]]")
  }

  // MARK: - Strikethrough parsing limitations

  @Test("Strikethrough parsing ceases across paragraph boundaries")
  func strikethroughCeasesAcrossParagraphs() {
    let input = """
    This ~~has a

    new paragraph~~.
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"This ~~has a\")],paragraph[text(\"new paragraph~~.\")]]")
  }
}

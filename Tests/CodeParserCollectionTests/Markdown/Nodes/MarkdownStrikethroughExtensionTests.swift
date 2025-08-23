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

  @Test("Simple strikethrough content")  
  func simpleStrikethroughContent() {
    let input = "~~simple~~"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strike[text(\"simple\")]]]")
  }

  @Test("Strikethrough with emphasis inside")
  func strikethroughWithEmphasisInside() {
    let input = "~~**bold**~~"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strike[strong[text(\"bold\")]]]]")
  }

  // @Test("Triple tildes should not create strikethrough")
  // func tripleTildesShouldNotCreateStrikethrough() {
  //   let input = "~~~text~~~"
  //   let result = parser.parse(input, language: language)

  //   // Triple tildes are treated as fenced code blocks in GFM, but with no language specified
  //   // If not at block level, they should be treated as text
  //   #expect(sig(result.root) == "document[paragraph[text(\"~~~text~~~\")]]")
  // }
}

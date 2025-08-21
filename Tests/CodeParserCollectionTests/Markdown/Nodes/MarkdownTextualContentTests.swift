import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Textual Content Tests - Spec 041")
struct MarkdownTextualContentTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Basic textual content with special characters parsed as plain text")
  func basicTextualContent() {
    let input = "hello $.;'there"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"hello $.;'there\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unicode characters preserved in textual content")
  func unicodeCharacters() {
    let input = "Foo χρῆν"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo χρῆν\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Internal spaces preserved verbatim in textual content")
  func internalSpacesPreserved() {
    let input = "Multiple     spaces"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Multiple     spaces\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

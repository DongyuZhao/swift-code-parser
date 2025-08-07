import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Reference Footnote Tests")
struct MarkdownReferenceFootnoteTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Reference definition parsing")
  func referenceDefinition() {
    let input = "[ref]: https://example.com"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let ref = result.root.children.first as? ReferenceNode {
      #expect(ref.identifier == "ref")
      #expect(ref.url == "https://example.com")
    } else {
      Issue.record("Expected ReferenceNode")
    }
  }

  @Test("Footnote definition and reference parsing")
  func footnoteDefinitionAndReference() {
    let input = "[^1]: Footnote text\nParagraph with reference[^1]"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let footnote = result.root.children.first as? FootnoteNode else {
      Issue.record("Expected FootnoteNode")
      return
    }
    #expect(footnote.identifier == "1")
    #expect(footnote.content == "Footnote text")
    guard let paragraph = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(paragraph.children.contains { $0 is FootnoteReferenceNode })
  }
}

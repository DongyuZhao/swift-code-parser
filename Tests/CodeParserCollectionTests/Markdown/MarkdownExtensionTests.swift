import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Extension Tests")
struct MarkdownExtensionTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Merged extension coverage (citations, footnotes, definition lists)

  @Test("Citation and footnote references parse with definitions")
  func ext_citationAndFootnoteRef() {
    let input = "[text](u) Citation[@id] and footnote[^1] \n\n[@id]: item\n[^1]: note"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let citationRefs = result.root.nodes(where: { $0.element == .citationReference })
    #expect(citationRefs.count == 1)
    let footnoteRefs = result.root.nodes(where: { $0.element == .footnoteReference })
    #expect(footnoteRefs.count == 1)
    let citationDefs = result.root.nodes(where: { $0.element == .citation })
    #expect(citationDefs.count == 1)
    let footnoteDefs = result.root.nodes(where: { $0.element == .footnote })
    #expect(footnoteDefs.count == 1)
  }

  @Test("Definition list with two items and trailing non-definition paragraph")
  func ext_definitionListEdges() {
    let input = """
      Term1
      : Definition 1
      Term2
      : Definition 2

      Not a term
      No colon line
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let list = result.root.first(where: { $0.element == .definitionList }) as? DefinitionListNode
    #expect(list != nil)
    #expect(list?.children.count == 2)
    let hasPara = result.root.children.contains { node in
      guard let m = node as? MarkdownNodeBase else { return false }
      return m.element == .paragraph
    }
    #expect(hasPara)
  }

  // MARK: - Additional Extension Footnote Variant Test

  @Test("Footnote basic reference + definition")
  func ext_footnoteBasic() {
    let input = "Here[^a]\n\n[^a]: note"
    let result = parser.parse(input, language: language)
    let refs = result.root.nodes(where: { $0.element == .footnoteReference })
    let defs = result.root.nodes(where: { $0.element == .footnote })
    #expect(refs.count == 1)
    #expect(defs.count == 1)
  }
}

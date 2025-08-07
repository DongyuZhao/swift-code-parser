import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Formula Extension Tests")
struct MarkdownFormulaTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Inline formula parsing")
  func inlineFormula() {
    let input = "Euler: $e^{i\\pi}+1=0$"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.first(where: { $0.element == .formula }) != nil)
  }

  @Test("Block formula parsing")
  func blockFormula() {
    let input = "$$x=1$$"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is FormulaBlockNode)
  }
}


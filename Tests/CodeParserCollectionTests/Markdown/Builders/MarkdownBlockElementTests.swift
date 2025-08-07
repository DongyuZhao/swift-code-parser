import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Block Element Tests")
struct MarkdownBlockElementTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Fenced code block parsing")
  func fencedCodeBlock() {
    let input = "```swift\nlet x = 1\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let code = result.root.children.first as? CodeBlockNode {
      #expect(code.language == "swift")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
  }

  @Test("Horizontal rule parsing")
  func horizontalRule() {
    let input = "---"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is ThematicBreakNode)
  }

  @Test("Unordered list parsing")
  func unorderedList() {
    let input = "- item"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    let list = result.root.children.first as? UnorderedListNode
    #expect(list != nil)
    #expect(list?.children().count == 1)
  }

  @Test("Strikethrough inline parsing")
  func strikethroughInline() {
    let input = "~~strike~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.first is StrikeNode)
  }

  @Test("Formula block parsing")
  func formulaBlock() {
    let input = "$$x=1$$"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is FormulaBlockNode)
  }

  @Test("Definition list parsing")
  func definitionList() {
    let input = "Term\n: Definition"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    let list = result.root.children.first as? DefinitionListNode
    #expect(list != nil)
    #expect(list?.children().count == 1)
  }

  @Test("Admonition block parsing")
  func admonitionBlock() {
    let input = "> [!NOTE]\n> hello"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is AdmonitionNode)
  }

  @Test("Custom container block parsing")
  func customContainerBlock() {
    let input = "::: custom\nhello\n:::"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is CustomContainerNode)
  }
}

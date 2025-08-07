import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown GFM Extension Tests")
struct MarkdownGFMTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Strikethrough parsing")
  func strikethrough() {
    let input = "~~strike~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.first(where: { $0.element == .strike }) != nil)
  }

  @Test("Task list parsing")
  func taskList() {
    let input = """
- [x] done
- [ ] todo
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let list = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    let items = list.children.compactMap { $0 as? TaskListItemNode }
    #expect(items.count == 2)
    #expect(items.first?.checked == true)
    #expect(items.last?.checked == false)
  }

  @Test("Table parsing")
  func table() {
    let input = """
| A | B |
|---|---|
| 1 | 2 |
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let table = result.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    let rows = table.children.compactMap { $0 as? TableRowNode }
    #expect(rows.count == 2)
    for row in rows {
      let cells = row.children.compactMap { $0 as? TableCellNode }
      #expect(cells.count == 2)
    }
  }
}


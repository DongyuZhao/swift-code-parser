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
    let input = "this is ~~strike~~ text"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 3)
    guard let text1 = para.children[0] as? TextNode,
      let strike = para.children[1] as? StrikeNode,
      let text2 = para.children[2] as? TextNode
    else {
      Issue.record("Expected TextNode, StrikeNode, TextNode")
      return
    }
    #expect(text1.content == "this is ")
    #expect(text2.content == " text")
    guard let strikeText = strike.children.first as? TextNode else {
      Issue.record("Expected TextNode inside StrikeNode")
      return
    }
    #expect(strikeText.content == "strike")
  }

  @Test("Strikethrough with nested inline elements")
  func strikethroughWithNested() {
    let input = "~~strike with `code` and *emphasis*~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let strike = para.children.first as? StrikeNode else {
      Issue.record("Expected StrikeNode")
      return
    }
    #expect(strike.children.count == 4)
    guard let text1 = strike.children[0] as? TextNode,
      let code = strike.children[1] as? InlineCodeNode,
      let text2 = strike.children[2] as? TextNode,
      let emphasis = strike.children[3] as? EmphasisNode
    else {
      Issue.record("Expected Text, Code, Text, Emphasis inside StrikeNode")
      return
    }
    #expect(text1.content == "strike with ")
    #expect(code.code == "code")
    #expect(text2.content == " and ")
    guard let emphasisText = emphasis.children.first as? TextNode
    else {
      Issue.record("Expected TextNode inside EmphasisNode")
      return
    }
    #expect(emphasisText.content == "emphasis")
  }

  @Test("Task list parsing")
  func taskList() {
    let input = """
- [x] done
- [ ] todo with `code`
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let list = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    let items = list.children.compactMap { $0 as? TaskListItemNode }
    #expect(items.count == 2)

    #expect(items[0].checked == true)
    guard let para1 = items[0].children.first as? ParagraphNode,
      let text1 = para1.children.first as? TextNode
    else {
      Issue.record("Expected ParagraphNode with TextNode in first task item")
      return
    }
    #expect(text1.content == "done")

    #expect(items[1].checked == false)
    guard let para2 = items[1].children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in second task item")
      return
    }
    #expect(para2.children.count == 2)
    guard let text2 = para2.children[0] as? TextNode,
      let code = para2.children[1] as? InlineCodeNode
    else {
      Issue.record("Expected TextNode and InlineCodeNode in second task item")
      return
    }
    #expect(text2.content == "todo with ")
    #expect(code.code == "code")
  }

  @Test("Table parsing")
  func table() {
    let input = """
| A | B |
|---|---|
| 1 | `code` |
| **strong** | 4 |
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let table = result.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    let rows = table.children.compactMap { $0 as? TableRowNode }
    #expect(rows.count == 3)

    // Header
    let headerCells = rows[0].children.compactMap { $0 as? TableCellNode }
    #expect(headerCells.count == 2)
    #expect((headerCells[0].children.first as? TextNode)?.content == "A")
    #expect((headerCells[1].children.first as? TextNode)?.content == "B")

    // Row 1
    let row1Cells = rows[1].children.compactMap { $0 as? TableCellNode }
    #expect(row1Cells.count == 2)
    #expect((row1Cells[0].children.first as? TextNode)?.content == "1")
    #expect((row1Cells[1].children.first as? InlineCodeNode)?.code == "code")

    // Row 2
    let row2Cells = rows[2].children.compactMap { $0 as? TableCellNode }
    #expect(row2Cells.count == 2)
    #expect(((row2Cells[0].children.first as? StrongNode)?.children.first as? TextNode)?.content == "strong")
    #expect((row2Cells[1].children.first as? TextNode)?.content == "4")
  }
}

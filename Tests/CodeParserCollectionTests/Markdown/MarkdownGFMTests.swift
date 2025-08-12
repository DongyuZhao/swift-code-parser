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

  // MARK: - Merged inline strike-related coverage

  @Test("Emphasis, strong and strike combined inline")
  func gfm_emphasisStrongStrikeCombined() {
    let input = "*em* **str** ~~del~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let hasEm = para?.children.contains { ($0 as? MarkdownNodeBase)?.element == .emphasis } ?? false
    let hasStrong =
      para?.children.contains { ($0 as? MarkdownNodeBase)?.element == .strong } ?? false
    let hasStrike =
      para?.children.contains { ($0 as? MarkdownNodeBase)?.element == .strike } ?? false
    #expect(hasEm && hasStrong && hasStrike)
  }

  @Test("Single tilde merged into surrounding text")
  func gfm_tildeMerge() {
    let input = "a ~ b"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    #expect(para?.children.count == 1)
    let text = para?.children.first as? TextNode
    #expect(text?.content == "a ~ b")
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

  @Test("Single tilde should not create strikethrough")
  func singleTildeLiteral() {
    let input = "~test~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    guard let text = para.children.first as? TextNode else {
      Issue.record("Expected TextNode only")
      return
    }
    #expect(text.content == "~test~")
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
    #expect(
      ((row2Cells[0].children.first as? StrongNode)?.children.first as? TextNode)?.content
        == "strong"
    )
    #expect((row2Cells[1].children.first as? TextNode)?.content == "4")
  }

  @Test("Table alignment parsing")
  func tableAlignment() {
    let input = """
      | A | B | C | D |
      |:--|:-:|--:|---|
      | 1 | 2  | 3  | 4 |
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let table = result.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.alignments.count == 4)
    #expect(table.alignments[0] == .left)
    #expect(table.alignments[1] == .center)
    #expect(table.alignments[2] == .right)
    #expect(table.alignments[3] == .none)
    let rows = table.children.compactMap { $0 as? TableRowNode }
    #expect(rows.count == 2)  // header + one data row
    let headerCells = rows[0].children.compactMap { $0 as? TableCellNode }
    #expect(headerCells.count == 4)
    #expect(headerCells[0].alignment == .left)
    #expect(headerCells[1].alignment == .center)
    #expect(headerCells[2].alignment == .right)
    #expect(headerCells[3].alignment == .none)
    let dataCells = rows[1].children.compactMap { $0 as? TableCellNode }
    #expect(dataCells.count == 4)
    #expect(dataCells[0].alignment == .left)
    #expect(dataCells[1].alignment == .center)
    #expect(dataCells[2].alignment == .right)
    #expect(dataCells[3].alignment == .none)
  }

  // MARK: - Added High-Value GFM-specific Tests

  @Test("Nested task list under unordered list")
  func nestedTaskList() {
    let input = "- [ ] parent\n  - child"
    let result = parser.parse(input, language: language)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    guard let parentItem = ulist.children.first as? TaskListItemNode else {
      Issue.record("First item should be TaskListItemNode")
      return
    }
    #expect(parentItem.checked == false)
    // Second child of root list should be nested list in parent
    let maybeNested = parentItem.children.first { $0 is UnorderedListNode }
    #expect(maybeNested != nil)
  }

  @Test("Invalid task list checkbox pattern not recognized")
  func invalidTaskCheckbox() {
    let input = "- [x ] bad"
    let result = parser.parse(input, language: language)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    guard let item = ulist.children.first as? ListItemNode else { return }
    _ = item  // silence unused
    // Should not produce any TaskListItemNode in the list
    let hasTask = ulist.children.contains { $0 is TaskListItemNode }
    #expect(hasTask == false)
  }

  @Test("Table escaped pipe and inline code containing pipe")
  func tableEscapedPipes() {
    let input = "| A | B |\n|---|---|\n| a\\|b | `c|d` |"
    let result = parser.parse(input, language: language)
    guard let table = result.root.children.first as? TableNode else { return }
    let rows = table.children.compactMap { $0 as? TableRowNode }
    #expect(rows.count == 2)
    let dataCells = rows[1].children.compactMap { $0 as? TableCellNode }
    #expect(dataCells.count == 2)
    let cell0Text = (dataCells[0].children.first as? TextNode)?.content
    #expect(cell0Text == "a|b")
    let code = dataCells[1].children.first as? InlineCodeNode
    #expect(code?.code.contains("c|d") == true)
  }

  @Test("Strikethrough containing emphasis nested")
  func strikeWithEmphasisNested() {
    let input = "~~*x*~~"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    guard let strike = para.children.first as? StrikeNode else { return }
    #expect(strike.children.contains { $0 is EmphasisNode })
  }

  @Test("Piped lines without separator should not form table")
  func noSeparatorNoTable() {
    let input = """
      | A | B |
      | 1 | 2 |
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    // Expect a single paragraph node, not a table
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode instead of TableNode")
      return
    }
    let concatenated = para.children.compactMap { (($0 as? TextNode)?.content) }.joined()
    #expect(concatenated.contains("| A | B |"))
  }

  @Test("Admonition callout header + one content line")
  func admonitionBasic() {
    let input = "> [!NOTE]\n> Content line"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard
      let node = result.root.children.first(where: {
        ($0 as? MarkdownNodeBase)?.element == .admonition
      }) as? AdmonitionNode
    else {
      Issue.record("Expected AdmonitionNode")
      return
    }
    #expect(node.kind == "note")
    let text = node.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "Content line")
  }

  @Test("Admonition captures multiple consecutive > lines")
  func admonitionMultipleLines() {
    let input = "> [!TIP]\n> Line 1\n> Line 2 with `code` and *em*"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let node =
      result.root.children.first(where: { ($0 as? MarkdownNodeBase)?.element == .admonition })
      as? AdmonitionNode
    #expect(node?.kind == "tip")
    // Expect inline children spanning both lines: Text, LineBreak, Text, InlineCode, Text, Emphasis
    #expect(node?.children.contains { $0 is InlineCodeNode } == true)
    #expect(node?.children.contains { $0 is EmphasisNode } == true)
    // Ensure both lines' text are present in order
    let concatenated = node?.children.compactMap { (($0 as? TextNode)?.content) }.joined(
      separator: "\n")
    #expect(concatenated?.contains("Line 1") == true)
    #expect(concatenated?.contains("Line 2") == true)
  }

  @Test("Admonition allows optional single space after > on header and content lines")
  func admonitionOptionalSpace() {
    let input = ">  [!WaRn]\n>  with *em* and `code`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard
      let node = result.root.children.first(where: {
        ($0 as? MarkdownNodeBase)?.element == .admonition
      }) as? AdmonitionNode
    else {
      Issue.record("Expected AdmonitionNode")
      return
    }
    #expect(node.kind == "warn")
    #expect(node.children.contains { $0 is EmphasisNode } == true)
    #expect(node.children.contains { $0 is InlineCodeNode } == true)
  }

  @Test("Admonition kind is case-insensitive and stored lowercase")
  func admonitionKindCaseInsensitive() {
    let input = "> [!TiP]\n> x"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let node =
      result.root.children.first(where: { ($0 as? MarkdownNodeBase)?.element == .admonition })
      as? AdmonitionNode
    #expect(node?.kind == "tip")
  }

  @Test("Header without following blockquote should not form admonition")
  func admonitionMissingSecondLine() {
    let input = "> [!WARNING]\nno quote here"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let hasAdmonition = result.root.children.contains {
      ($0 as? MarkdownNodeBase)?.element == .admonition
    }
    #expect(!hasAdmonition)
  }
}

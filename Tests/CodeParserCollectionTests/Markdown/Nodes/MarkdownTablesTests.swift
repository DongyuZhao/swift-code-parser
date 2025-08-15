import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Tables (GFM)")
struct MarkdownTablesTests {
  private let h = MarkdownTestHarness()

  // 198
  @Test("Spec 198: Basic table with header and body")
  func spec198() {
    let input = "| foo | bar |\n| --- | --- |\n| baz | bim |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    // Table should have two children: header then content
    #expect(table.children.count == 2)
    guard let header = table.children.first as? TableHeaderNode,
      let content = table.children.last as? TableContentNode
    else {
      Issue.record("Expected TableHeaderNode then TableContentNode")
      return
    }
    // Header/body distinction is validated via signature below
    // Header row and cells
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hCells = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(hCells.count == 2)
    #expect(hCells[0].alignment == .none)
    #expect(hCells[1].alignment == .none)
    #expect(innerText(hCells[0]) == "foo")
    #expect(innerText(hCells[1]) == "bar")
    // Body cells (first row in content)
    guard let row = content.children.first as? TableRowNode else {
      Issue.record("Missing body row")
      return
    }
    let bCells = row.children.compactMap { $0 as? TableCellNode }
    #expect(bCells.count == 2)
    #expect(bCells[0].alignment == .none)
    #expect(bCells[1].alignment == .none)
    #expect(innerText(bCells[0]) == "baz")
    #expect(innerText(bCells[1]) == "bim")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"foo\")],table_cell(align:none)[text(\"bar\")]]],table_content[table_row[table_cell(align:none)[text(\"baz\")],table_cell(align:none)[text(\"bim\")]]]]"
    )
  }

  // 199
  @Test("Spec 199: Alignments center and right")
  func spec199() {
    let input = "| abc | defghi |\n:-: | -----------:\nbar | baz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    // Alignments inferred from separator line; validated via cell alignments and signature below
    // Children: header + content
    #expect(table.children.count == 2)
    guard let header = table.children.first as? TableHeaderNode,
      let content = table.children.last as? TableContentNode
    else {
      Issue.record("Expected TableHeaderNode + TableContentNode")
      return
    }
    // Header row validated by signature
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hCells = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(hCells.count == 2)
    #expect(hCells[0].alignment == .center)
    #expect(hCells[1].alignment == .right)
    #expect(innerText(hCells[0]) == "abc")
    #expect(innerText(hCells[1]) == "defghi")
    guard let row = content.children.first as? TableRowNode else {
      Issue.record("Missing body row")
      return
    }
    let bCells = (row.children.compactMap { $0 as? TableCellNode })
    #expect(bCells.count == 2)
    #expect(bCells[0].alignment == .center)
    #expect(bCells[1].alignment == .right)
    #expect(innerText(bCells[0]) == "bar")
    #expect(innerText(bCells[1]) == "baz")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:center)[text(\"abc\")],table_cell(align:right)[text(\"defghi\")]]],table_content[table_row[table_cell(align:center)[text(\"bar\")],table_cell(align:right)[text(\"baz\")]]]]"
    )
  }

  // 200
  @Test("Spec 200: Escaped pipes and inline code/strong inside cells")
  func spec200() {
    let input = "| f\\|oo  |\n| ------ |\n| b `\\|` az |\n| b **\\|** im |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)  // header + content
    guard let header = table.children.first as? TableHeaderNode else {
      Issue.record("Missing header")
      return
    }
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hCells = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(hCells.count == 1)
    #expect(innerText(hCells[0]) == "f|oo")
    // First body row
    guard let content = table.children.last as? TableContentNode else {
      Issue.record("Missing content")
      return
    }
    guard let r1 = content.children.first as? TableRowNode else {
      Issue.record("Missing row1")
      return
    }
    let c1 = r1.children.compactMap { $0 as? TableCellNode }
    #expect(c1.count == 1)
    // inline code with literal pipe
    #expect(childrenTypes(c1[0]).contains(.text))
    #expect(findNodes(in: c1[0], ofType: InlineCodeNode.self).count == 1)
    let c1Inlines = c1[0].children
    #expect((c1Inlines.first as? TextNode)?.content == "b ")
    #expect((c1Inlines.dropFirst().first as? InlineCodeNode)?.code == "|")
    #expect((c1Inlines.last as? TextNode)?.content == " az")
    // Second body row
    guard let r2 = content.children.dropFirst().first as? TableRowNode else {
      Issue.record("Missing row2")
      return
    }
    let c2 = r2.children.compactMap { $0 as? TableCellNode }
    #expect(c2.count == 1)
    let c2Inlines = c2[0].children
    #expect((c2Inlines.first as? TextNode)?.content == "b ")
    #expect(c2Inlines.contains { $0 is StrongNode })
    #expect((c2Inlines.last as? TextNode)?.content == " im")
    if let strong = c2Inlines.first(where: { $0 is StrongNode }) as? StrongNode {
      #expect(innerText(strong) == "|")
    }
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"f|oo\")]]],table_content[table_row[table_cell(align:none)[text(\"b \")],code(\"|\"),text(\" az\")],table_row[table_cell(align:none)[text(\"b \")],strong[text(\"|\")],text(\" im\")]]]]"
    )
  }

  // 201
  @Test("Spec 201: Table followed by blockquote")
  func spec201() {
    let input = "| abc | def |\n| --- | --- |\n| bar | baz |\n> bar\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    if let header = table.children.first as? TableHeaderNode,
      let headerRow = header.children.first as? TableRowNode
    {
      let cells = headerRow.children.compactMap { $0 as? TableCellNode }
      #expect(cells.count == 2)
      #expect(innerText(cells[0]) == "abc")
      #expect(innerText(cells[1]) == "def")
    }
    if let content = table.children.last as? TableContentNode,
      let row = content.children.first as? TableRowNode
    {
      let cells = row.children.compactMap { $0 as? TableCellNode }
      #expect(cells.count == 2)
      #expect(innerText(cells[0]) == "bar")
      #expect(innerText(cells[1]) == "baz")
    }
    guard let bq = r.root.children.last as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    let p = findNodes(in: bq, ofType: ParagraphNode.self).first
    #expect(p != nil)
    #expect(innerText(p!) == "bar")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"baz\")]]]],blockquote[paragraph[text(\"bar\")]]]"
    )
  }

  // 202
  @Test("Spec 202: Table with short row and following paragraph")
  func spec202() {
    let input = "| abc | def |\n| --- | --- |\n| bar | baz |\nbar\n\nbar\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    // header cells
    if let header = table.children.first as? TableHeaderNode,
      let headerRow = header.children.first as? TableRowNode
    {
      let h = headerRow.children.compactMap { $0 as? TableCellNode }
      #expect(h.count == 2)
      #expect(innerText(h[0]) == "abc")
      #expect(innerText(h[1]) == "def")
    }
    // first body row
    if let content = table.children.last as? TableContentNode,
      let r1 = content.children.first as? TableRowNode
    {
      let c = r1.children.compactMap { $0 as? TableCellNode }
      #expect(c.count == 2)
      #expect(innerText(c[0]) == "bar")
      #expect(innerText(c[1]) == "baz")
    }
    // second body row: one cell only, second empty
    if let content = table.children.last as? TableContentNode,
      let r2 = content.children.dropFirst().first as? TableRowNode
    {
      let c = r2.children.compactMap { $0 as? TableCellNode }
      #expect(c.count >= 1)
      #expect(innerText(c[0]) == "bar")
    }
    guard let p = r.root.children.last as? ParagraphNode else {
      Issue.record("Expected trailing paragraph")
      return
    }
    #expect(innerText(p) == "bar")
    // Strict sig
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)],table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)]]],paragraph[text(\"bar\")]]"
    )
  }

  // 203
  @Test("Spec 203: Not a table when separator doesn't match header columns")
  func spec203() {
    let input = "| abc | def |\n| --- |\n| bar |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(
      sig(p)
        == "paragraph[text(\"| abc | def |\"),line_break(soft),text(\"| --- |\"),line_break(soft),text(\"| bar |\")]"
    )
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"| abc | def |\"),line_break(soft),text(\"| --- |\"),line_break(soft),text(\"| bar |\")]]"
    )
  }

  // 204
  @Test("Spec 204: Rows with missing or extra cells")
  func spec204() {
    let input = "| abc | def |\n| --- | --- |\n| bar |\n| bar | baz | boo |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    // header
    if let header = table.children.first as? TableHeaderNode,
      let headerRow = header.children.first as? TableRowNode
    {
      let c = headerRow.children.compactMap { $0 as? TableCellNode }
      #expect(c.count == 2)
      #expect(innerText(c[0]) == "abc")
      #expect(innerText(c[1]) == "def")
    }
    // first body row: second cell empty
    if let content = table.children.last as? TableContentNode,
      let r1 = content.children.first as? TableRowNode
    {
      let c = r1.children.compactMap { $0 as? TableCellNode }
      #expect(c.count >= 1)
      #expect(innerText(c[0]) == "bar")
    }
    // second body row: third cell ignored
    if let content = table.children.last as? TableContentNode,
      let r2 = content.children.dropFirst().first as? TableRowNode
    {
      let c = r2.children.compactMap { $0 as? TableCellNode }
      #expect(c.count == 2)
      #expect(innerText(c[0]) == "bar")
      #expect(innerText(c[1]) == "baz")
    }
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)],table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"baz\")]]]]]"
    )
  }

  // 205
  @Test("Spec 205: Table with header only")
  func spec205() {
    let input = "| abc | def |\n| --- | --- |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 1)
    guard let header = table.children.first as? TableHeaderNode else {
      Issue.record("Expected header")
      return
    }
    // Header row validated by signature
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Expected header row")
      return
    }
    let cells = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(cells.count == 2)
    #expect(innerText(cells[0]) == "abc")
    #expect(innerText(cells[1]) == "def")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]]]]]"
    )
  }

  // Custom 1
  @Test("Custom: alignment-like tokens in header cells are text, not alignment")
  func specTC1() {
    let input = "| :--: | --: |\n| --- | --- |\n| a | b |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    guard let header = table.children.first as? TableHeaderNode,
      let content = table.children.last as? TableContentNode
    else {
      Issue.record("Expected header and one body row")
      return
    }
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hc = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(hc.count == 2)
    #expect(hc[0].alignment == .none)
    #expect(hc[1].alignment == .none)
    #expect(innerText(hc[0]) == ":--:")
    #expect(innerText(hc[1]) == "--:")
    guard let row = content.children.first as? TableRowNode else {
      Issue.record("Missing body row")
      return
    }
    let bc = row.children.compactMap { $0 as? TableCellNode }
    #expect(bc.count == 2)
    #expect(innerText(bc[0]) == "a")
    #expect(innerText(bc[1]) == "b")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\":--:\")],table_cell(align:none)[text(\"--:\")]]],table_content[table_row[table_cell(align:none)[text(\"a\")],table_cell(align:none)[text(\"b\")]]]]"
    )
  }

  // Custom 2
  @Test("Custom: alignment-like tokens in body cells are text, not alignment")
  func specTC2() {
    let input = "| a | b |\n| --- | --- |\n| :-: | :-- |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    guard let header = table.children.first as? TableHeaderNode,
      let content = table.children.last as? TableContentNode
    else {
      Issue.record("Expected header and one body row")
      return
    }
    guard let headerRow2 = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hc = headerRow2.children.compactMap { $0 as? TableCellNode }
    #expect(hc.count == 2)
    #expect(innerText(hc[0]) == "a")
    #expect(innerText(hc[1]) == "b")
    guard let row = content.children.first as? TableRowNode else {
      Issue.record("Missing body row")
      return
    }
    let bc = row.children.compactMap { $0 as? TableCellNode }
    #expect(bc.count == 2)
    #expect(bc[0].alignment == .none)
    #expect(bc[1].alignment == .none)
    #expect(innerText(bc[0]) == ":-:")
    #expect(innerText(bc[1]) == ":--")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:none)[text(\"a\")],table_cell(align:none)[text(\"b\")]]],table_content[table_row[table_cell(align:none)[text(\":-:\")],table_cell(align:none)[text(\":--\")]]]]"
    )
  }

  // Custom 3
  @Test("Custom: left/center/right align per column")
  func specTC3() {
    let input = "| L | C | R |\n| :-- | :-: | --: |\n| l1 | c1 | r1 |\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let table = r.root.children.first as? TableNode else {
      Issue.record("Expected TableNode")
      return
    }
    #expect(table.children.count == 2)
    guard let header = table.children.first as? TableHeaderNode,
      let content = table.children.last as? TableContentNode
    else {
      Issue.record("Expected header + content")
      return
    }
    guard let headerRow = header.children.first as? TableRowNode else {
      Issue.record("Missing header row")
      return
    }
    let hc = headerRow.children.compactMap { $0 as? TableCellNode }
    #expect(hc.count == 3)
    #expect(hc[0].alignment == .left)
    #expect(hc[1].alignment == .center)
    #expect(hc[2].alignment == .right)
    #expect(innerText(hc[0]) == "L")
    #expect(innerText(hc[1]) == "C")
    #expect(innerText(hc[2]) == "R")
    guard let row = content.children.first as? TableRowNode else {
      Issue.record("Missing body row")
      return
    }
    let bc = row.children.compactMap { $0 as? TableCellNode }
    #expect(bc.count == 3)
    #expect(bc[0].alignment == .left)
    #expect(bc[1].alignment == .center)
    #expect(bc[2].alignment == .right)
    #expect(innerText(bc[0]) == "l1")
    #expect(innerText(bc[1]) == "c1")
    #expect(innerText(bc[2]) == "r1")
    #expect(
      sig(r.root)
        == "document[table[table_header[table_row[table_cell(align:left)[text(\"L\")],table_cell(align:center)[text(\"C\")],table_cell(align:right)[text(\"R\")]]],table_content[table_row[table_cell(align:left)[text(\"l1\")],table_cell(align:center)[text(\"c1\")],table_cell(align:right)[text(\"r1\")]]]]"
    )
  }
}

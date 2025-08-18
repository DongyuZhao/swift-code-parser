import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tables Extension Tests - Spec 023")
struct MarkdownTablesExtensionTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Basic table with header, delimiter row, and data rows")
  func basicTableWithHeaderDelimiterRowAndDataRows() {
    let input = """
    | foo | bar |
    | --- | --- |
    | baz | bim |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headers = findNodes(in: tables[0], ofType: TableHeaderNode.self)
    #expect(headers.count == 1)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let headerRows = findNodes(in: headers[0], ofType: TableRowNode.self)
    #expect(headerRows.count == 1)

    let contentRows = findNodes(in: content[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 1)

    let headerCells = findNodes(in: headerRows[0], ofType: TableCellNode.self)
    #expect(headerCells.count == 2)
    #expect(innerText(headerCells[0]) == "foo")
    #expect(innerText(headerCells[1]) == "bar")
    #expect(headerCells[0].alignment == .none)
    #expect(headerCells[1].alignment == .none)

    let dataCells = findNodes(in: contentRows[0], ofType: TableCellNode.self)
    #expect(dataCells.count == 2)
    #expect(innerText(dataCells[0]) == "baz")
    #expect(innerText(dataCells[1]) == "bim")
    #expect(dataCells[0].alignment == .none)
    #expect(dataCells[1].alignment == .none)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"foo\")],table_cell(align:none)[text(\"bar\")]]],table_content[table_row[table_cell(align:none)[text(\"baz\")],table_cell(align:none)[text(\"bim\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table with center and right alignment using colons in delimiter")
  func tableWithCenterAndRightAlignmentUsingColonsInDelimiter() {
    let input = """
    | abc | defghi |
    :-: | -----------:
    bar | baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headers = findNodes(in: tables[0], ofType: TableHeaderNode.self)
    #expect(headers.count == 1)

    let headerRows = findNodes(in: headers[0], ofType: TableRowNode.self)
    #expect(headerRows.count == 1)

    let headerCells = findNodes(in: headerRows[0], ofType: TableCellNode.self)
    #expect(headerCells.count == 2)
    #expect(innerText(headerCells[0]) == "abc")
    #expect(innerText(headerCells[1]) == "defghi")
    #expect(headerCells[0].alignment == .center)
    #expect(headerCells[1].alignment == .right)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let contentRows = findNodes(in: content[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 1)

    let dataCells = findNodes(in: contentRows[0], ofType: TableCellNode.self)
    #expect(dataCells.count == 2)
    #expect(innerText(dataCells[0]) == "bar")
    #expect(innerText(dataCells[1]) == "baz")
    #expect(dataCells[0].alignment == .center)
    #expect(dataCells[1].alignment == .right)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:center)[text(\"abc\")],table_cell(align:right)[text(\"defghi\")]]],table_content[table_row[table_cell(align:center)[text(\"bar\")],table_cell(align:right)[text(\"baz\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table cells with escaped pipes and inline formatting")
  func tableCellsWithEscapedPipesAndInlineFormatting() {
    let input = """
    | f\\|oo  |
    | ------ |
    | b `\\|` az |
    | b **\\|** im |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headers = findNodes(in: tables[0], ofType: TableHeaderNode.self)
    #expect(headers.count == 1)

    let headerCells = findNodes(in: headers[0], ofType: TableCellNode.self)
    #expect(headerCells.count == 1)
    #expect(innerText(headerCells[0]) == "f|oo")

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let contentRows = findNodes(in: content[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 2)

    // First data row with inline code
    let firstRowCells = findNodes(in: contentRows[0], ofType: TableCellNode.self)
    #expect(firstRowCells.count == 1)
    let codeNodes = findNodes(in: firstRowCells[0], ofType: CodeSpanNode.self)
    #expect(codeNodes.count == 1)
    #expect(codeNodes[0].code == "|")

    // Second data row with strong emphasis
    let secondRowCells = findNodes(in: contentRows[1], ofType: TableCellNode.self)
    #expect(secondRowCells.count == 1)
    let strongNodes = findNodes(in: secondRowCells[0], ofType: StrongNode.self)
    #expect(strongNodes.count == 1)
    #expect(innerText(strongNodes[0]) == "|")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"f|oo\")]]],table_content[table_row[table_cell(align:none)[text(\"b \"),code(\"|\"),text(\" az\")]],table_row[table_cell(align:none)[text(\"b \"),strong[text(\"|\")],text(\" im\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table broken by blockquote")
  func tableBrokenByBlockquote() {
    let input = """
    | abc | def |
    | --- | --- |
    | bar | baz |
    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let contentRows = findNodes(in: tables[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 2) // header + 1 data row

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"baz\")]]]],blockquote[paragraph[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table broken by blank line and paragraph")
  func tableBrokenByBlankLineAndParagraph() {
    let input = """
    | abc | def |
    | --- | --- |
    | bar | baz |
    bar

    bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    // Should have header + 2 data rows (including the "bar" line)
    let allRows = findNodes(in: tables[0], ofType: TableRowNode.self)
    #expect(allRows.count == 3)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "bar")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"baz\")]],table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"\")]]]],paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table not recognized when header and delimiter row have different cell counts")
  func tableNotRecognizedWhenHeaderAndDelimiterRowHaveDifferentCellCounts() {
    let input = """
    | abc | def |
    | --- |
    | bar |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a table due to mismatched cell counts
    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 0)

    // Should create a paragraph instead
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let expectedSig = "document[paragraph[text(\"| abc | def |\"),text(\"| --- |\"),text(\"| bar |\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table rows with varying cell counts handle empty and excess cells")
  func tableRowsWithVaryingCellCountsHandleEmptyAndExcessCells() {
    let input = """
    | abc | def |
    | --- | --- |
    | bar |
    | bar | baz | boo |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let contentRows = findNodes(in: content[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 2)

    // First data row should have 2 cells (one empty)
    let firstRowCells = findNodes(in: contentRows[0], ofType: TableCellNode.self)
    #expect(firstRowCells.count == 2)
    #expect(innerText(firstRowCells[0]) == "bar")
    #expect(innerText(firstRowCells[1]) == "")

    // Second data row should have 2 cells (excess ignored)
    let secondRowCells = findNodes(in: contentRows[1], ofType: TableCellNode.self)
    #expect(secondRowCells.count == 2)
    #expect(innerText(secondRowCells[0]) == "bar")
    #expect(innerText(secondRowCells[1]) == "baz")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]],table_content[table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"\")]],table_row[table_cell(align:none)[text(\"bar\")],table_cell(align:none)[text(\"baz\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table with only header and delimiter row creates no tbody")
  func tableWithOnlyHeaderAndDelimiterRowCreatesNoTbody() {
    let input = """
    | abc | def |
    | --- | --- |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headers = findNodes(in: tables[0], ofType: TableHeaderNode.self)
    #expect(headers.count == 1)

    let headerCells = findNodes(in: headers[0], ofType: TableCellNode.self)
    #expect(headerCells.count == 2)
    #expect(innerText(headerCells[0]) == "abc")
    #expect(innerText(headerCells[1]) == "def")

    // Should not have table content since no data rows
    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 0)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"abc\")],table_cell(align:none)[text(\"def\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table with left alignment using leading colon")
  func tableWithLeftAlignmentUsingLeadingColon() {
    let input = """
    | left | normal |
    | :--- | ------ |
    | data | value  |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headerCells = findNodes(in: tables[0], ofType: TableCellNode.self)
    #expect(headerCells.count >= 2)
    #expect(headerCells[0].alignment == .left)
    #expect(headerCells[1].alignment == .none)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let dataCells = findNodes(in: content[0], ofType: TableCellNode.self)
    #expect(dataCells.count >= 2)
    #expect(dataCells[0].alignment == .left)
    #expect(dataCells[1].alignment == .none)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:left)[text(\"left\")],table_cell(align:none)[text(\"normal\")]]],table_content[table_row[table_cell(align:left)[text(\"data\")],table_cell(align:none)[text(\"value\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table cells with inline elements preserve formatting")
  func tableCellsWithInlineElementsPreserveFormatting() {
    let input = """
    | **bold** | *italic* | `code` |
    | -------- | -------- | ------ |
    | normal   | text     | here   |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headers = findNodes(in: tables[0], ofType: TableHeaderNode.self)
    #expect(headers.count == 1)

    let headerCells = findNodes(in: headers[0], ofType: TableCellNode.self)
    #expect(headerCells.count == 3)

    // Check for strong formatting
    let strongNodes = findNodes(in: headerCells[0], ofType: StrongNode.self)
    #expect(strongNodes.count == 1)
    #expect(innerText(strongNodes[0]) == "bold")

    // Check for emphasis formatting
    let emphasisNodes = findNodes(in: headerCells[1], ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)
    #expect(innerText(emphasisNodes[0]) == "italic")

    // Check for code formatting
    let codeNodes = findNodes(in: headerCells[2], ofType: CodeSpanNode.self)
    #expect(codeNodes.count == 1)
    #expect(codeNodes[0].code == "code")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[strong[text(\"bold\")]],table_cell(align:none)[emphasis[text(\"italic\")]],table_cell(align:none)[code(\"code\")]]],table_content[table_row[table_cell(align:none)[text(\"normal\")],table_cell(align:none)[text(\"text\")],table_cell(align:none)[text(\"here\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table without leading and trailing pipes still recognized")
  func tableWithoutLeadingAndTrailingPipesStillRecognized() {
    let input = """
    foo | bar
    --- | ---
    baz | bim
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headerCells = findNodes(in: tables[0], ofType: TableCellNode.self)
    #expect(headerCells.count >= 2)
    #expect(innerText(headerCells[0]) == "foo")
    #expect(innerText(headerCells[1]) == "bar")

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let dataCells = findNodes(in: content[0], ofType: TableCellNode.self)
    #expect(dataCells.count >= 2)
    #expect(innerText(dataCells[0]) == "baz")
    #expect(innerText(dataCells[1]) == "bim")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"foo\")],table_cell(align:none)[text(\"bar\")]]],table_content[table_row[table_cell(align:none)[text(\"baz\")],table_cell(align:none)[text(\"bim\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table with mixed alignment types in single table")
  func tableWithMixedAlignmentTypesInSingleTable() {
    let input = """
    | left | center | right | none |
    | :--- | :----: | ----: | ---- |
    | L    | C      | R     | N    |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let headerCells = findNodes(in: tables[0], ofType: TableCellNode.self)
    #expect(headerCells.count >= 4)
    #expect(headerCells[0].alignment == .left)
    #expect(headerCells[1].alignment == .center)
    #expect(headerCells[2].alignment == .right)
    #expect(headerCells[3].alignment == .none)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let dataCells = findNodes(in: content[0], ofType: TableCellNode.self)
    #expect(dataCells.count >= 4)
    #expect(dataCells[0].alignment == .left)
    #expect(dataCells[1].alignment == .center)
    #expect(dataCells[2].alignment == .right)
    #expect(dataCells[3].alignment == .none)

    let expectedSig = "document[table[table_header[table_row[table_cell(align:left)[text(\"left\")],table_cell(align:center)[text(\"center\")],table_cell(align:right)[text(\"right\")],table_cell(align:none)[text(\"none\")]]],table_content[table_row[table_cell(align:left)[text(\"L\")],table_cell(align:center)[text(\"C\")],table_cell(align:right)[text(\"R\")],table_cell(align:none)[text(\"N\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table with empty cells in various positions")
  func tableWithEmptyCellsInVariousPositions() {
    let input = """
    | | middle | |
    | --- | --- | --- |
    | empty | | end |
    | | center | |
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let tables = findNodes(in: result.root, ofType: TableNode.self)
    #expect(tables.count == 1)

    let content = findNodes(in: tables[0], ofType: TableContentNode.self)
    #expect(content.count == 1)

    let contentRows = findNodes(in: content[0], ofType: TableRowNode.self)
    #expect(contentRows.count == 2)

    // First data row
    let firstRowCells = findNodes(in: contentRows[0], ofType: TableCellNode.self)
    #expect(firstRowCells.count == 3)
    #expect(innerText(firstRowCells[0]) == "empty")
    #expect(innerText(firstRowCells[1]) == "")
    #expect(innerText(firstRowCells[2]) == "end")

    // Second data row
    let secondRowCells = findNodes(in: contentRows[1], ofType: TableCellNode.self)
    #expect(secondRowCells.count == 3)
    #expect(innerText(secondRowCells[0]) == "")
    #expect(innerText(secondRowCells[1]) == "center")
    #expect(innerText(secondRowCells[2]) == "")

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"middle\")],table_cell(align:none)[text(\"\")]]],table_content[table_row[table_cell(align:none)[text(\"empty\")],table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"end\")]],table_row[table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"center\")],table_cell(align:none)[text(\"\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

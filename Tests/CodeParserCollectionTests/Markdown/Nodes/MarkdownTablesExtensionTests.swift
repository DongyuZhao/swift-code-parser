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

    // First data row with inline code

    // Second data row with strong emphasis

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

    // Should have header + 2 data rows (including the "bar" line)

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

    // Should not create a table due to mismatched cell counts

    // Should create a paragraph instead

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

    // First data row should have 2 cells (one empty)

    // Second data row should have 2 cells (excess ignored)

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

    // Should not have table content since no data rows

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

    let expectedSig = "document[table[table_header[table_row[table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"middle\")],table_cell(align:none)[text(\"\")]]],table_content[table_row[table_cell(align:none)[text(\"empty\")],table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"end\")]],table_row[table_cell(align:none)[text(\"\")],table_cell(align:none)[text(\"center\")],table_cell(align:none)[text(\"\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

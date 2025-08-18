import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Setext Headings Tests - Spec 016")
struct MarkdownSetextHeadingsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple setext headings with equals and dashes")
  func simpleSetextHeadings() {
    let input = """
    Foo *bar*
    =========

    Foo *bar*
    ---------
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 1)
    #expect(headers[1].level == 2)

    // Verify inline parsing in headers
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\")]],heading(level:2)[text(\"Foo \"),emphasis[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Heading content can span multiple lines")
  func multilineHeadingContent() {
    let input = """
    Foo *bar
    baz*
    ====
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)

    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\nbaz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Leading and trailing whitespace is stripped from heading content")
  func whitespaceStrippedFromContent() {
    let input = """
      Foo *bar
    baz*\t
    ====
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)

    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\nbaz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Underline can be any length")
  func underlineAnyLength() {
    let input = """
    Foo
    -------------------------

    Foo
    =
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\")],heading(level:1)[text(\"Foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Heading content can be indented up to three spaces")
  func contentIndentedUpToThreeSpaces() {
    let input = """
       Foo
    ---

      Foo
    -----

      Foo
      ===
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 3)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 2)
    #expect(headers[2].level == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\")],heading(level:2)[text(\"Foo\")],heading(level:1)[text(\"Foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indent is too much - creates code block instead")
  func fourSpacesIndentTooMuch() {
    let input = """
        Foo
        ---

        Foo
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "Foo\n---\n\nFoo")

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"Foo\n---\n\nFoo\"),thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Underline can be indented up to three spaces")
  func underlineIndentedUpToThreeSpaces() {
    let input = """
    Foo
       ----
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indent for underline is too much")
  func underlineFourSpacesIndentTooMuch() {
    let input = """
    Foo
        ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\n---\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Underline cannot contain internal spaces")
  func underlineCannotContainInternalSpaces() {
    let input = """
    Foo
    = =

    Foo
    --- -
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\n= =\")],paragraph[text(\"Foo\")],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Trailing spaces in content line do not cause line break")
  func trailingSpacesInContentLine() {
    let input = """
    Foo
    -----
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash at end of content line does not cause line break")
  func backslashAtEndOfContentLine() {
    let input = """
    Foo\\
    ----
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\\\\\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block structure indicators take precedence over inline structure")
  func blockStructureTakesPrecedence() {
    let input = """
    `Foo
    ----
    `

    <a title="a lot
    ---
    of dashes"/>
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 2)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"`Foo\")],paragraph[text(\"`\")],heading(level:2)[text(\"<a title=\\\"a lot\")],paragraph[text(\"of dashes\\\"/>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Underline cannot be lazy continuation line in blockquote")
  func underlineNotLazyContinuationInBlockquote() {
    let input = """
    > Foo
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[blockquote[paragraph[text(\"Foo\")]],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multi-line content in blockquote remains paragraph")
  func multilineContentInBlockquoteRemainsParagraph() {
    let input = """
    > foo
    bar
    ===
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[blockquote[paragraph[text(\"foo\nbar\n===\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Underline cannot be lazy continuation line in list item")
  func underlineNotLazyContinuationInListItem() {
    let input = """
    - Foo
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]]],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph content becomes part of heading without blank line")
  func paragraphContentBecomesPartOfHeading() {
    let input = """
    Foo
    Bar
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 0)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\nBar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Setext headings can be mixed with thematic breaks without blank lines")
  func setextHeadingsMixedWithThematicBreaks() {
    let input = """
    ---
    Foo
    ---
    Bar
    ---
    Baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 2)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break,heading(level:2)[text(\"Foo\")],heading(level:2)[text(\"Bar\")],paragraph[text(\"Baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty setext headings are not allowed")
  func emptySetextHeadingsNotAllowed() {
    let input = """

    ====
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"====\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Dashes are interpreted as thematic break when they cannot form setext heading")
  func dashesAsThematicBreakWhenCannotFormHeading() {
    let input = """
    ---
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break,thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item followed by dashes creates thematic break")
  func listItemFollowedByDashesCreatesThematicBreak() {
    let input = """
    - foo
    -----
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code block followed by dashes creates thematic break")
  func codeBlockFollowedByDashesCreatesThematicBreak() {
    let input = """
        foo
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "foo")

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"foo\"),thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blockquote followed by dashes creates thematic break")
  func blockquoteFollowedByDashesCreatesThematicBreak() {
    let input = """
    > foo
    -----
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[blockquote[paragraph[text(\"foo\")]],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Escaped blockquote marker can form setext heading")
  func escapedBlockquoteMarkerCanFormSetextHeading() {
    let input = """
    \\> foo
    ------
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 0)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"> foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Interpretation 1: Blank line separates paragraph from heading")
  func interpretation1BlankLineSeparatesParagraphFromHeading() {
    let input = """
    Foo

    bar
    ---
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\")],heading(level:2)[text(\"bar\")],paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Interpretation 2: Blank lines around thematic break")
  func interpretation2BlankLinesAroundThematicBreak() {
    let input = """
    Foo
    bar

    ---

    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\nbar\")],thematic_break,paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Alternative thematic break that cannot be setext underline")
  func alternativeThematicBreakNotSetextUnderline() {
    let input = """
    Foo
    bar
    * * *
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\nbar\")],thematic_break,paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Interpretation 3: Escaped dashes prevent setext heading")
  func interpretation3EscapedDashesPreventSetextHeading() {
    let input = """
    Foo
    bar
    \\---
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 0)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\nbar\n---\nbaz\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

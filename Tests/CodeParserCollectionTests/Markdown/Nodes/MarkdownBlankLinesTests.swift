import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Blank Lines Tests - Spec 022")
struct MarkdownBlankLinesTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Blank lines between block elements are ignored and at document boundaries")
  func blankLinesBetweenBlockElementsAreIgnoredAndAtDocumentBoundaries() {
    let input = """


    aaa


    # aaa


    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should only create a paragraph and a heading, ignoring all blank lines
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "aaa")

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "aaa")

    // Should not create any blank line nodes or extra content


    let expectedSig = "document[paragraph[text(\"aaa\")],heading(level:1)[text(\"aaa\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple consecutive blank lines have same effect as single blank line")
  func multipleConsecutiveBlankLinesHaveSameEffectAsSingleBlankLine() {
    let input = """
    first paragraph



    second paragraph
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "first paragraph")
    #expect(innerText(paragraphs[1]) == "second paragraph")

    // Multiple blank lines should not create additional structure


    let expectedSig = "document[paragraph[text(\"first paragraph\")],paragraph[text(\"second paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines at beginning of document are ignored")
  func blankLinesAtBeginningOfDocumentAreIgnored() {
    let input = """



    content
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "content")

    // Leading blank lines should not create any structure


    let expectedSig = "document[paragraph[text(\"content\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines at end of document are ignored")
  func blankLinesAtEndOfDocumentAreIgnored() {
    let input = """
    content



    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "content")

    // Trailing blank lines should not create any structure


    let expectedSig = "document[paragraph[text(\"content\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines between different block element types")
  func blankLinesBetweenDifferentBlockElementTypes() {
    let input = """
    paragraph


    ## heading


    > blockquote


    - list item
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

  let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
  #expect(paragraphs.count == 3) // top-level paragraph + paragraph inside blockquote + paragraph inside list item
  #expect(innerText(paragraphs[0]) == "paragraph")

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 2)
    #expect(innerText(headers[0]) == "heading")

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let lists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(lists.count == 1)


    let expectedSig = "document[paragraph[text(\"paragraph\")],heading(level:2)[text(\"heading\")],blockquote[paragraph[text(\"blockquote\")]],unordered_list(level:1)[list_item[paragraph[text(\"list item\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Document with only blank lines creates empty document")
  func documentWithOnlyBlankLinesCreatesEmptyDocument() {
    let input = """




    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should create an empty document with no content
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 0)

    let expectedSig = "document"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines do not interfere with block element recognition")
  func blankLinesDoNotInterfereWithBlockElementRecognition() {
    let input = """

    ```
    code block
    ```

    * list
    * items

    1. ordered
    2. list

    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "code block")

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)


    let expectedSig = "document[code_block(\"code block\"),unordered_list(level:1)[list_item[paragraph[text(\"list\")]],list_item[paragraph[text(\"items\")]]],ordered_list(level:1)[list_item[paragraph[text(\"ordered\")]],list_item[paragraph[text(\"list\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines within code blocks are preserved")
  func blankLinesWithinCodeBlocksArePreserved() {
    let input = """
    ```
    line 1

    line 3
    ```
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "line 1\n\nline 3")

    let expectedSig = "document[code_block(\"line 1\\n\\nline 3\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines separate paragraphs but not preserved as nodes")
  func blankLinesSeparateParagraphsButNotPreservedAsNodes() {
    let input = """
    first

    second

    third
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 3)
    #expect(innerText(paragraphs[0]) == "first")
    #expect(innerText(paragraphs[1]) == "second")
    #expect(innerText(paragraphs[2]) == "third")

    // Blank lines should not be preserved as nodes


    let expectedSig = "document[paragraph[text(\"first\")],paragraph[text(\"second\")],paragraph[text(\"third\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines before and after thematic breaks")
  func blankLinesBeforeAndAfterThematicBreaks() {
    let input = """
    paragraph


    ---


    another paragraph
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "paragraph")
    #expect(innerText(paragraphs[1]) == "another paragraph")

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)


    let expectedSig = "document[paragraph[text(\"paragraph\")],thematic_break,paragraph[text(\"another paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed blank lines and content preserve only meaningful structure")
  func mixedBlankLinesAndContentPreserveOnlyMeaningfulStructure() {
    let input = """


    # Header



    Content paragraph.



    ## Subheader



    More content.


    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "Header")
    #expect(headers[1].level == 2)
    #expect(innerText(headers[1]) == "Subheader")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "Content paragraph.")
    #expect(innerText(paragraphs[1]) == "More content.")

    // All blank lines should be ignored


    let expectedSig = "document[heading(level:1)[text(\"Header\")],paragraph[text(\"Content paragraph.\")],heading(level:2)[text(\"Subheader\")],paragraph[text(\"More content.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single blank line has same effect as multiple blank lines")
  func singleBlankLineHasSameEffectAsMultipleBlankLines() {
    let input1 = """
    para1

    para2
    """

    let input2 = """
    para1



    para2
    """

    let result1 = parser.parse(input1, language: language)
    let result2 = parser.parse(input2, language: language)

    #expect(result1.errors.isEmpty)
    #expect(result2.errors.isEmpty)

    // Both should produce identical AST structure
    #expect(sig(result1.root) == sig(result2.root))

    let expectedSig = "document[paragraph[text(\"para1\")],paragraph[text(\"para2\")]]"
    #expect(sig(result1.root) == expectedSig)
    #expect(sig(result2.root) == expectedSig)
  }

  @Test("Blank lines containing only whitespace are treated as blank")
  func blankLinesContainingOnlyWhitespaceAreTreatedAsBlank() {
    let input = """
    first paragraph

    second paragraph
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "first paragraph")
    #expect(innerText(paragraphs[1]) == "second paragraph")

    let expectedSig = "document[paragraph[text(\"first paragraph\")],paragraph[text(\"second paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

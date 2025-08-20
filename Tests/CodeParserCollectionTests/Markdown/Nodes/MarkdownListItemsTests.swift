import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown List Items Tests - Spec 025")
struct MarkdownListItemsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Basic case - ordered list item with mixed content blocks")
  func basicCaseOrderedListItemWithMixedContentBlocks() {
    let input = """
    1.  A paragraph
        with two lines.

            indented code

        > A block quote.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "indented code")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indentation determines list item continuation - insufficient indentation creates separate paragraph")
  func indentationDeterminesListItemContinuationInsufficientIndentationCreatesSeparateParagraph() {
    let input = """
    - one

     two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "one")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2) // One in list item, one outside

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],paragraph[text(\"two\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Sufficient indentation includes content in list item as continuation paragraph")
  func sufficientIndentationIncludesContentInListItemAsContinuationParagraph() {
    let input = """
    - one

      two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "one")
    #expect(innerText(paragraphs[1]) == "two")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")],paragraph[text(\"two\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Wide list marker requires more indentation - insufficient creates code block")
  func wideListMarkerRequiresMoreIndentationInsufficientCreatesCodeBlock() {
    let input = """
     -    one

         two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "one")

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == " two")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],code_block(\" two\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Wide list marker with sufficient indentation includes content in list item")
  func wideListMarkerWithSufficientIndentationIncludesContentInListItem() {
    let input = """
     -    one

          two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "one")
    #expect(innerText(paragraphs[1]) == "two")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")],paragraph[text(\"two\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested blockquotes determine indentation based on containing context")
  func nestedBlockquotesDetermineIndentationBasedOnContainingContext() {
    let input = """
       > > 1.  one
    >>
    >>     two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let nestedBlockquotes = findNodes(in: blockquotes[0], ofType: BlockquoteNode.self)
    #expect(nestedBlockquotes.count == 1)

    let orderedLists = findNodes(in: nestedBlockquotes[0], ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "one")
    #expect(innerText(paragraphs[1]) == "two")

    let expectedSig = "document[blockquote[blockquote[ordered_list(level:1)[list_item[paragraph[text(\"one\")],paragraph[text(\"two\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Insufficient indentation in nested context excludes content from list item")
  func insufficientIndentationInNestedContextExcludesContentFromListItem() {
    let input = """
    >>- one
    >>
      >  > two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let nestedBlockquotes = findNodes(in: blockquotes[0], ofType: BlockquoteNode.self)
    #expect(nestedBlockquotes.count == 1)

    let unorderedLists = findNodes(in: nestedBlockquotes[0], ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "one")

    let paragraphs = findNodes(in: nestedBlockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2) // One in list item, one outside

    let expectedSig = "document[blockquote[blockquote[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],paragraph[text(\"two\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List marker requires space - no space creates paragraph")
  func listMarkerRequiresSpaceNoSpaceCreatesParagraph() {
    let input = """
    -one

    2.two
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "-one")
    #expect(innerText(paragraphs[1]) == "2.two")

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 0)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let expectedSig = "document[paragraph[text(\"-one\")],paragraph[text(\"2.two\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item can contain blocks separated by multiple blank lines")
  func listItemCanContainBlocksSeparatedByMultipleBlankLines() {
    let input = """
    - foo


      bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "foo")
    #expect(innerText(paragraphs[1]) == "bar")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item can contain any kind of block elements")
  func listItemCanContainAnyKindOfBlockElements() {
    let input = """
    1.  foo

        ```
        bar
        ```

        baz

        > bam
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "foo")
    #expect(innerText(paragraphs[1]) == "baz")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "bar")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\"),paragraph[text(\"baz\")],blockquote[paragraph[text(\"bam\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item with indented code block preserves empty lines verbatim")
  func listItemWithIndentedCodeBlockPreservesEmptyLinesVerbatim() {
    let input = """
    - Foo

          bar


          baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "Foo")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "bar\n\n\nbaz")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")],code_block(\"bar\\n\\n\\nbaz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Ordered list start numbers must be nine digits or less - valid case")
  func orderedListStartNumbersMustBeNineDigitsOrLessValidCase() {
    let input = "123456789. ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "ok")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Ordered list start numbers with ten digits create paragraph not list")
  func orderedListStartNumbersWithTenDigitsCreateParagraphNotList() {
    let input = "1234567890. not ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "1234567890. not ok")

    let expectedSig = "document[paragraph[text(\"1234567890. not ok\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may begin with zeros - simple zero start")
  func startNumberMayBeginWithZerosSimpleZeroStart() {
    let input = "0. ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "ok")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may begin with zeros - leading zeros case")
  func startNumberMayBeginWithZerosLeadingZerosCase() {
    let input = "003. ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "ok")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may not be negative creates paragraph")
  func startNumberMayNotBeNegativeCreatesParagraph() {
    let input = "-1. not ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "-1. not ok")

    let expectedSig = "document[paragraph[text(\"-1. not ok\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Item starting with indented code requires specific indentation - six spaces")
  func itemStartingWithIndentedCodeRequiresSpecificIndentationSixSpaces() {
    let input = """
    - foo

          bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "bar")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Item starting with indented code requires specific indentation - eleven spaces for wide marker")
  func itemStartingWithIndentedCodeRequiresSpecificIndentationElevenSpacesForWideMarker() {
    let input = """
      10.  foo

               bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "bar")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First block as indented code requires one space after list marker")
  func firstBlockAsIndentedCodeRequiresOneSpaceAfterListMarker() {
    let input = """
    1.     indented code

       paragraph

           more code
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 2)
    #expect(codeBlocks[0].source == "indented code")
    #expect(codeBlocks[1].source == "more code")

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "paragraph")

    let expectedSig = "document[ordered_list(level:1)[list_item[code_block(\"indented code\"),paragraph[text(\"paragraph\")],code_block(\"more code\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Additional space in code block interpreted as internal spacing")
  func additionalSpaceInCodeBlockInterpretedAsInternalSpacing() {
    let input = """
    1.      indented code

       paragraph

           more code
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 2)
    #expect(codeBlocks[0].source == " indented code")
    #expect(codeBlocks[1].source == "more code")

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "paragraph")

    let expectedSig = "document[ordered_list(level:1)[list_item[code_block(\" indented code\"),paragraph[text(\"paragraph\")],code_block(\"more code\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Three-space indent prevents list item formation creates separate paragraphs")
  func threeSpaceIndentPreventsListItemFormationCreatesSeparateParagraphs() {
    let input = """
    -    foo

      bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "foo")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2) // One in list item, one outside

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Proper indentation allows list item formation with continuation")
  func properIndentationAllowsListItemFormationWithContinuation() {
    let input = """
    -  foo

       bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "foo")
    #expect(innerText(paragraphs[1]) == "bar")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item starting with blank line followed by content")
  func listItemStartingWithBlankLineFollowedByContent() {
    let input = """
    -
      foo
    -
      ```
      bar
      ```
    -
          baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // First item
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "foo")

    // Second item
    let codeBlocks2 = findNodes(in: listItems[1], ofType: CodeBlockNode.self)
    #expect(codeBlocks2.count == 1)
    #expect(codeBlocks2[0].source == "bar")

    // Third item
    let codeBlocks3 = findNodes(in: listItems[2], ofType: CodeBlockNode.self)
    #expect(codeBlocks3.count == 1)
    #expect(codeBlocks3[0].source == "baz")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[code_block(\"bar\")],list_item[code_block(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item can begin with at most one blank line")
  func listItemCanBeginWithAtMostOneBlankLine() {
    let input = """
    -

      foo
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    // List item should be empty
    let itemChildren = listItems[0].children
    #expect(itemChildren.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let expectedSig = "document[unordered_list(level:1)[list_item],paragraph[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty bullet list item between non-empty items")
  func emptyBulletListItemBetweenNonEmptyItems() {
    let input = """
    - foo
    -
    - bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    #expect(innerText(listItems[0]) == "foo")

    // Second item should be empty
    let item2Children = listItems[1].children
    #expect(item2Children.count == 0)

    #expect(innerText(listItems[2]) == "bar")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty ordered list item between non-empty items")
  func emptyOrderedListItemBetweenNonEmptyItems() {
    let input = """
    1. foo
    2.
    3. bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    #expect(innerText(listItems[0]) == "foo")

    // Second item should be empty
    let item2Children = listItems[1].children
    #expect(item2Children.count == 0)

    #expect(innerText(listItems[2]) == "bar")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single empty list item")
  func singleEmptyListItem() {
    let input = "*"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    // List item should be empty
    let itemChildren = listItems[0].children
    #expect(itemChildren.count == 0)

    let expectedSig = "document[unordered_list(level:1)[list_item]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty list item cannot interrupt paragraph")
  func emptyListItemCannotInterruptParagraph() {
    let input = """
    foo
    *

    foo
    1.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "foo\n*")
    #expect(innerText(paragraphs[1]) == "foo\n1.")

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 0)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let expectedSig = "document[paragraph[text(\"foo\"),text(\"*\")],paragraph[text(\"foo\"),text(\"1.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item indented one space maintains structure")
  func listItemIndentedOneSpaceMaintainsStructure() {
    let input = """
     1.  A paragraph
         with two lines.

             indented code

         > A block quote.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "indented code")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indent creates code block instead of list")
  func fourSpacesIndentCreatesCodeBlockInsteadOfList() {
    let input = """
        1.  A paragraph
            with two lines.

                indented code

            > A block quote.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "1.  A paragraph\n    with two lines.\n\n        indented code\n\n    > A block quote.")

    let expectedSig = "document[code_block(\"1.  A paragraph\\n    with two lines.\\n\\n        indented code\\n\\n    > A block quote.\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lazy continuation lines in list items")
  func lazyContinuationLinesInListItems() {
    let input = """
      1.  A paragraph
    with two lines.

              indented code

          > A block quote.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "A paragraph")
    #expect(textNodes[1].content == "with two lines.")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "indented code")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Partial lazy continuation line indentation")
  func partialLazyContinuationLineIndentation() {
    let input = """
      1.  A paragraph
        with two lines.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "A paragraph")
    #expect(textNodes[1].content == "with two lines.")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),text(\"with two lines.\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lazy continuation in nested structures - blockquote and list")
  func lazyContinuationInNestedStructuresBlockquoteAndList() {
    let input = """
    > 1. > Blockquote
    continued here.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let orderedLists = findNodes(in: blockquotes[0], ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let nestedBlockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(nestedBlockquotes.count == 1)

    let paragraphs = findNodes(in: nestedBlockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "Blockquote")
    #expect(textNodes[1].content == "continued here.")

    let expectedSig = "document[blockquote[ordered_list(level:1)[list_item[blockquote[paragraph[text(\"Blockquote\"),text(\"continued here.\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Sublists require proper indentation for nesting - sufficient indentation")
  func sublistsRequireProperIndentationForNestingSufficientIndentation() {
    let input = """
    - foo
      - bar
        - baz
          - boo
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let level1Items = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(level1Items.count == 1)

    let level2Lists = findNodes(in: level1Items[0], ofType: UnorderedListNode.self)
    #expect(level2Lists.count == 1)

    let level2Items = findNodes(in: level2Lists[0], ofType: ListItemNode.self)
    #expect(level2Items.count == 1)

    let level3Lists = findNodes(in: level2Items[0], ofType: UnorderedListNode.self)
    #expect(level3Lists.count == 1)

    let level3Items = findNodes(in: level3Lists[0], ofType: ListItemNode.self)
    #expect(level3Items.count == 1)

    let level4Lists = findNodes(in: level3Items[0], ofType: UnorderedListNode.self)
    #expect(level4Lists.count == 1)

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")],unordered_list(level:3)[list_item[paragraph[text(\"baz\")],unordered_list(level:4)[list_item[paragraph[text(\"boo\")]]]]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Sublists with insufficient indentation create separate lists")
  func sublistsWithInsufficientIndentationCreateSeparateLists() {
    let input = """
    - foo
     - bar
      - baz
       - boo
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 4)

    #expect(innerText(listItems[0]) == "foo")
    #expect(innerText(listItems[1]) == "bar")
    #expect(innerText(listItems[2]) == "baz")
    #expect(innerText(listItems[3]) == "boo")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]],list_item[paragraph[text(\"boo\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Wide ordered marker requires more indentation for sublists")
  func wideOrderedMarkerRequiresMoreIndentationForSublists() {
    let input = """
    10) foo
        - bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let orderedListItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(orderedListItems.count == 1)

    let unorderedLists = findNodes(in: orderedListItems[0], ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let unorderedListItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(unorderedListItems.count == 1)
    #expect(innerText(unorderedListItems[0]) == "bar")

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List as first block in list item - simple nesting")
  func listAsFirstBlockInListItemSimpleNesting() {
    let input = "- - foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let outerLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(outerLists.count == 1)

    let outerItems = findNodes(in: outerLists[0], ofType: ListItemNode.self)
    #expect(outerItems.count == 1)

    let innerLists = findNodes(in: outerItems[0], ofType: UnorderedListNode.self)
    #expect(innerLists.count == 1)

    let innerItems = findNodes(in: innerLists[0], ofType: ListItemNode.self)
    #expect(innerItems.count == 1)
    #expect(innerText(innerItems[0]) == "foo")

    let expectedSig = "document[unordered_list(level:1)[list_item[unordered_list(level:2)[list_item[paragraph[text(\"foo\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed list types as first block in list item")
  func mixedListTypesAsFirstBlockInListItem() {
    let input = "1. - 2. foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let orderedItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(orderedItems.count == 1)

    let unorderedLists = findNodes(in: orderedItems[0], ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let unorderedItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(unorderedItems.count == 1)

    let nestedOrderedLists = findNodes(in: unorderedItems[0], ofType: OrderedListNode.self)
    #expect(nestedOrderedLists.count == 1)

    let nestedOrderedItems = findNodes(in: nestedOrderedLists[0], ofType: ListItemNode.self)
    #expect(nestedOrderedItems.count == 1)
    #expect(innerText(nestedOrderedItems[0]) == "foo")

    let expectedSig = "document[ordered_list(level:1)[list_item[unordered_list(level:1)[list_item[ordered_list(level:2)[list_item[paragraph[text(\"foo\")]]]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item can contain heading with setext underline")
  func listItemCanContainHeadingWithSetextUnderline() {
    let input = """
    - # Foo
    - Bar
      ---
      baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // First item with ATX heading
    let atxHeaders = findNodes(in: listItems[0], ofType: HeaderNode.self)
    #expect(atxHeaders.count == 1)
    #expect(atxHeaders[0].level == 1)
    #expect(innerText(atxHeaders[0]) == "Foo")

    // Second item with setext heading
    let setextHeaders = findNodes(in: listItems[1], ofType: HeaderNode.self)
    #expect(setextHeaders.count == 1)
    #expect(setextHeaders[0].level == 2)
    #expect(innerText(setextHeaders[0]) == "Bar")

    let paragraphs = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "baz")

    let expectedSig = "document[unordered_list(level:1)[list_item[heading(level:1)[text(\"Foo\")]],list_item[heading(level:2)[text(\"Bar\")],paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

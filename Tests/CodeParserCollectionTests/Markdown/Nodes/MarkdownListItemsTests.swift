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

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")],code_block(\"bar\n\n\nbaz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Ordered list start numbers must be nine digits or less - valid case")
  func orderedListStartNumbersMustBeNineDigitsOrLessValidCase() {
    let input = "123456789. ok"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Ordered list start numbers with ten digits create paragraph not list")
  func orderedListStartNumbersWithTenDigitsCreateParagraphNotList() {
    let input = "1234567890. not ok"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"1234567890. not ok\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may begin with zeros - simple zero start")
  func startNumberMayBeginWithZerosSimpleZeroStart() {
    let input = "0. ok"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may begin with zeros - leading zeros case")
  func startNumberMayBeginWithZerosLeadingZerosCase() {
    let input = "003. ok"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Start number may not be negative creates paragraph")
  func startNumberMayNotBeNegativeCreatesParagraph() {
    let input = "-1. not ok"
    let result = parser.parse(input, language: language)

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

    // First item

    // Second item

    // Third item

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

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single empty list item")
  func singleEmptyListItem() {
    let input = "*"
    let result = parser.parse(input, language: language)

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

  let expectedSig = "document[paragraph[text(\"foo\"),line_break(soft),text(\"*\")],paragraph[text(\"foo\"),line_break(soft),text(\"1.\")]]"
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

    let expectedSig = "document[code_block(\"1.  A paragraph\n    with two lines.\n\n        indented code\n\n    > A block quote.\")]"
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

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List as first block in list item - simple nesting")
  func listAsFirstBlockInListItemSimpleNesting() {
    let input = "- - foo"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[unordered_list(level:2)[list_item[paragraph[text(\"foo\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed list types as first block in list item")
  func mixedListTypesAsFirstBlockInListItem() {
    let input = "1. - 2. foo"
    let result = parser.parse(input, language: language)

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

    // First item with ATX heading

    // Second item with setext heading

    let expectedSig = "document[unordered_list(level:1)[list_item[heading(level:1)[text(\"Foo\")]],list_item[heading(level:2)[text(\"Bar\")],paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Lists Tests - Spec 027")
struct MarkdownListsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Changing bullet delimiter starts new list")
  func changingBulletDelimiterStartsNewList() {
    let input = """
    - foo
    - bar
    + baz
    """
    let result = parser.parse(input, language: language)

    // First list with - markers

    // Second list with + marker

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],unordered_list(level:1)[list_item[paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Changing ordered list delimiter starts new list")
  func changingOrderedListDelimiterStartsNewList() {
    let input = """
    1. foo
    2. bar
    3) baz
    """
    let result = parser.parse(input, language: language)

    // First list with . delimiter

    // Second list with ) delimiter

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],ordered_list(level:1)[list_item[paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List can interrupt paragraph without blank line")
  func listCanInterruptParagraphWithoutBlankLine() {
    let input = """
    Foo
    - bar
    - baz
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"Foo\")],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hard-wrapped numeral does not trigger list when not starting with 1")
  func hardWrappedNumeralDoesNotTriggerListWhenNotStartingWith1() {
    let input = """
    The number of windows in my house is
    14.  The number of doors is 6.
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"The number of windows in my house is\"),line_break(soft),text(\"14.  The number of doors is 6.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hard-wrapped numeral starting with 1 does trigger list")
  func hardWrappedNumeralStartingWith1DoesTriggerList() {
    let input = """
    The number of windows in my house is
    1.  The number of doors is 6.
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"The number of windows in my house is\")],ordered_list(level:1)[list_item[paragraph[text(\"The number of doors is 6.\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines between items create loose list")
  func blankLinesBetweenItemsCreateLooseList() {
    let input = """
    - foo

    - bar

    - baz
    """
    let result = parser.parse(input, language: language)

    // In loose lists, each item should contain a paragraph

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested list with blank lines creates loose outer list")
  func nestedListWithBlankLinesCreatesLooseOuterList() {
    let input = """
    - foo
      - bar
        - baz

          bim
    """
    let result = parser.parse(input, language: language)

    // Check nested structure

    // The deepest item should have two paragraphs due to blank line

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")],unordered_list(level:3)[list_item[paragraph[text(\"baz\")],paragraph[text(\"bim\")]]]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML comment separates consecutive lists")
  func htmlCommentSeparatesConsecutiveLists() {
    let input = """
    - foo
    - bar

    <!-- -->

    - baz
    - bim
    """
    let result = parser.parse(input, language: language)

    // First list

    // HTML comment

    // Second list

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],html_block(name:\"\",content:\"<!-- -->\"),unordered_list(level:1)[list_item[paragraph[text(\"baz\")]],list_item[paragraph[text(\"bim\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML comment prevents code block interpretation")
  func htmlCommentPreventsCodeBlockInterpretation() {
    let input = """
    -   foo

        notcode

    -   foo

    <!-- -->

        code
    """
    let result = parser.parse(input, language: language)

    // First item should have two paragraphs

    // Second item should have one paragraph

    // HTML comment

    // Code block after comment

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"notcode\")]],list_item[paragraph[text(\"foo\")]]],html_block(name:\"\",content:\"<!-- -->\"),code_block(\"code\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List items at different indentation levels treated as same level")
  func listItemsAtDifferentIndentationLevelsTreatedAsSameLevel() {
    let input = """
    - a
     - b
      - c
       - d
      - e
     - f
    - g
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]],list_item[paragraph[text(\"d\")]],list_item[paragraph[text(\"e\")]],list_item[paragraph[text(\"f\")]],list_item[paragraph[text(\"g\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Ordered list items at different indentation levels")
  func orderedListItemsAtDifferentIndentationLevels() {
    let input = """
    1. a

      2. b

       3. c
    """
    let result = parser.parse(input, language: language)

    // All items should be paragraphs due to blank lines

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item indented more than three spaces becomes continuation")
  func listItemIndentedMoreThanThreeSpacesBecomesContainuation() {
    let input = """
    - a
     - b
      - c
       - d
        - e
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]],list_item[paragraph[text(\"d\"),line_break(soft),text(\"- e\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four space indentation creates code block after blank line")
  func fourSpaceIndentationCreatesCodeBlockAfterBlankLine() {
    let input = """
    1. a

      2. b

        3. c
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]]],code_block(\"3. c\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Loose list with blank line between items")
  func looseListWithBlankLineBetweenItems() {
    let input = """
    - a
    - b

    - c
    """
    let result = parser.parse(input, language: language)

    // All items should be wrapped in paragraphs in loose list

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Loose list with empty second item")
  func looseListWithEmptySecondItem() {
    let input = """
    * a
    *

    * c
    """
    let result = parser.parse(input, language: language)

    // First item

    // Second item should be empty

    // Third item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item,list_item[paragraph[text(\"c\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Loose list with item containing two block elements")
  func looseListWithItemContainingTwoBlockElements() {
    let input = """
    - a
    - b

      c
    - d
    """
    let result = parser.parse(input, language: language)

    // All items should be wrapped in paragraphs in loose list

    // Second item has two paragraphs due to blank line

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")],paragraph[text(\"c\")]],list_item[paragraph[text(\"d\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Loose list with reference definition in item")
  func looseListWithReferenceDefinitionInItem() {
    let input = """
    - a
    - b

      [ref]: /url
    - d
    """
    let result = parser.parse(input, language: language)

    // All items should be wrapped in paragraphs in loose list

    // Check for reference definition

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"d\")]]],reference(id:\"ref\",url:\"/url\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tight list with blank lines in code block")
  func tightListWithBlankLinesInCodeBlock() {
    let input = """
    - a
    - ```
      b

      ```
    - c
    """
    let result = parser.parse(input, language: language)

    // First item - just text (tight list)

    // Second item with code block

    // Third item - just text (tight list)

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[code_block(\"b\n\n\n\")],list_item[paragraph[text(\"c\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tight outer list with loose sublist")
  func tightOuterListWithLooseSublist() {
    let input = """
    - a
      - b

        c
    - d
    """
    let result = parser.parse(input, language: language)

    // First item contains a sublist

    // Sublist item should have two paragraphs (loose)

    // Second top-level item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")],paragraph[text(\"c\")]]]],list_item[paragraph[text(\"d\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tight list with blank line inside blockquote")
  func tightListWithBlankLineInsideBlockquote() {
    let input = """
    * a
      > b
      >
    * c
    """
    let result = parser.parse(input, language: language)

    // First item contains text and blockquote

    // Second item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],blockquote[paragraph[text(\"b\")]]],list_item[paragraph[text(\"c\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tight list with consecutive block elements")
  func tightListWithConsecutiveBlockElements() {
    let input = """
    - a
      > b
      ```
      c
      ```
    - d
    """
    let result = parser.parse(input, language: language)

    // First item contains paragraph, blockquote, and code block

    // Second item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],blockquote[paragraph[text(\"b\")]],code_block(\"c\")],list_item[paragraph[text(\"d\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single paragraph list is tight")
  func singleParagraphListIsTight() {
    let input = "- a"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Simple nested list is tight")
  func simpleNestedListIsTight() {
    let input = """
    - a
      - b
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Loose list with blank line between code block and paragraph")
  func looseListWithBlankLineBetweenCodeBlockAndParagraph() {
    let input = """
    1. ```
       foo
       ```

       bar
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[ordered_list(level:1)[list_item[code_block(\"foo\"),paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Outer loose list with inner tight list")
  func outerLooseListWithInnerTightList() {
    let input = """
    * foo
      * bar

      baz
    """
    let result = parser.parse(input, language: language)

    // Top level item should have paragraph, sublist, and another paragraph

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")]]],paragraph[text(\"baz\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple sublists with loose outer list")
  func multipleSublistsWithLooseOuterList() {
    let input = """
    - a
      - b
      - c

    - d
      - e
      - f
    """
    let result = parser.parse(input, language: language)

    // First top-level item

    // Second top-level item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]],list_item[paragraph[text(\"d\")],unordered_list(level:2)[list_item[paragraph[text(\"e\")]],list_item[paragraph[text(\"f\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

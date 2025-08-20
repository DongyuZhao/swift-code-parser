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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 2)

    // First list with - markers
    let firstListItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(firstListItems.count == 2)
    #expect(innerText(firstListItems[0]) == "foo")
    #expect(innerText(firstListItems[1]) == "bar")

    // Second list with + marker
    let secondListItems = findNodes(in: unorderedLists[1], ofType: ListItemNode.self)
    #expect(secondListItems.count == 1)
    #expect(innerText(secondListItems[0]) == "baz")

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
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 2)

    // First list with . delimiter
    let firstListItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(firstListItems.count == 2)
    #expect(innerText(firstListItems[0]) == "foo")
    #expect(innerText(firstListItems[1]) == "bar")

    // Second list with ) delimiter
    let secondListItems = findNodes(in: orderedLists[1], ofType: ListItemNode.self)
    #expect(secondListItems.count == 1)
    #expect(innerText(secondListItems[0]) == "baz")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "Foo")

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)
    #expect(innerText(listItems[0]) == "bar")
    #expect(innerText(listItems[1]) == "baz")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "The number of windows in my house is\n14.  The number of doors is 6.")

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 0)

    let expectedSig = "document[paragraph[text(\"The number of windows in my house is\"),text(\"14.  The number of doors is 6.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hard-wrapped numeral starting with 1 does trigger list")
  func hardWrappedNumeralStartingWith1DoesTriggerList() {
    let input = """
    The number of windows in my house is
    1.  The number of doors is 6.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "The number of windows in my house is")

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "The number of doors is 6.")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // In loose lists, each item should contain a paragraph
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "foo")

    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "bar")

    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "baz")

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
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let topLevelItems = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 1)

    // Check nested structure
    let level2Lists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(level2Lists.count == 1)

    let level2Items = findNodes(in: level2Lists[0], ofType: ListItemNode.self)
    #expect(level2Items.count == 1)

    let level3Lists = findNodes(in: level2Items[0], ofType: UnorderedListNode.self)
    #expect(level3Lists.count == 1)

    let level3Items = findNodes(in: level3Lists[0], ofType: ListItemNode.self)
    #expect(level3Items.count == 1)

    // The deepest item should have two paragraphs due to blank line
    let deepParagraphs = findNodes(in: level3Items[0], ofType: ParagraphNode.self)
    #expect(deepParagraphs.count == 2)
    #expect(innerText(deepParagraphs[0]) == "baz")
    #expect(innerText(deepParagraphs[1]) == "bim")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 2)

    // First list
    let firstListItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(firstListItems.count == 2)
    #expect(innerText(firstListItems[0]) == "foo")
    #expect(innerText(firstListItems[1]) == "bar")

    // HTML comment
    let htmlBlocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    #expect(htmlBlocks.count == 1)
    #expect(htmlBlocks[0].content == "<!-- -->")

    // Second list
    let secondListItems = findNodes(in: unorderedLists[1], ofType: ListItemNode.self)
    #expect(secondListItems.count == 2)
    #expect(innerText(secondListItems[0]) == "baz")
    #expect(innerText(secondListItems[1]) == "bim")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // First item should have two paragraphs
    let firstItemParagraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(firstItemParagraphs.count == 2)
    #expect(innerText(firstItemParagraphs[0]) == "foo")
    #expect(innerText(firstItemParagraphs[1]) == "notcode")

    // Second item should have one paragraph
    let secondItemParagraphs = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(secondItemParagraphs.count == 1)
    #expect(innerText(secondItemParagraphs[0]) == "foo")

    // HTML comment
    let htmlBlocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    #expect(htmlBlocks.count == 1)

    // Code block after comment
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "code")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 7)

    #expect(innerText(listItems[0]) == "a")
    #expect(innerText(listItems[1]) == "b")
    #expect(innerText(listItems[2]) == "c")
    #expect(innerText(listItems[3]) == "d")
    #expect(innerText(listItems[4]) == "e")
    #expect(innerText(listItems[5]) == "f")
    #expect(innerText(listItems[6]) == "g")

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
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // All items should be paragraphs due to blank lines
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "b")

    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "c")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 4)

    #expect(innerText(listItems[0]) == "a")
    #expect(innerText(listItems[1]) == "b")
    #expect(innerText(listItems[2]) == "c")
    #expect(innerText(listItems[3]) == "d\n- e")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]],list_item[paragraph[text(\"d\"),text(\"- e\")]]]]"
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
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "b")

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "3. c")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // All items should be wrapped in paragraphs in loose list
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "b")

    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "c")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // First item
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    // Second item should be empty
    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 0)

    // Third item
    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "c")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // All items should be wrapped in paragraphs in loose list
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    // Second item has two paragraphs due to blank line
    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 2)
    #expect(innerText(paragraphs2[0]) == "b")
    #expect(innerText(paragraphs2[1]) == "c")

    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "d")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // All items should be wrapped in paragraphs in loose list
    let paragraphs1 = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "a")

    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "b")

    let paragraphs3 = findNodes(in: listItems[2], ofType: ParagraphNode.self)
    #expect(paragraphs3.count == 1)
    #expect(innerText(paragraphs3[0]) == "d")

    // Check for reference definition
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)
    #expect(references[0].identifier == "ref")
    #expect(references[0].url == "/url")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // First item - just text (tight list)
    #expect(innerText(listItems[0]) == "a")

    // Second item with code block
    let codeBlocks = findNodes(in: listItems[1], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "b\n\n\n")

    // Third item - just text (tight list)
    #expect(innerText(listItems[2]) == "c")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[code_block(\"b\\n\\n\\n\")],list_item[paragraph[text(\"c\")]]]]"
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
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let topLevelItems = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 2)

    // First item contains a sublist
    let subLists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(subLists.count == 1)

    let subItems = findNodes(in: subLists[0], ofType: ListItemNode.self)
    #expect(subItems.count == 1)

    // Sublist item should have two paragraphs (loose)
    let subParagraphs = findNodes(in: subItems[0], ofType: ParagraphNode.self)
    #expect(subParagraphs.count == 2)
    #expect(innerText(subParagraphs[0]) == "b")
    #expect(innerText(subParagraphs[1]) == "c")

    // Second top-level item
    #expect(innerText(topLevelItems[1]) == "d")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // First item contains text and blockquote
    #expect(innerText(listItems[0]) == "ab")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let blockquoteParagraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(blockquoteParagraphs.count == 1)
    #expect(innerText(blockquoteParagraphs[0]) == "b")

    // Second item
    #expect(innerText(listItems[1]) == "c")

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
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // First item contains paragraph, blockquote, and code block
    let firstItemParagraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(firstItemParagraphs.count == 1)
    #expect(innerText(firstItemParagraphs[0]) == "a")

    let blockquotes = findNodes(in: listItems[0], ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let blockquoteParagraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(blockquoteParagraphs.count == 1)
    #expect(innerText(blockquoteParagraphs[0]) == "b")

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "c")

    // Second item
    #expect(innerText(listItems[1]) == "d")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],blockquote[paragraph[text(\"b\")]],code_block(\"c\")],list_item[paragraph[text(\"d\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single paragraph list is tight")
  func singleParagraphListIsTight() {
    let input = "- a"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "a")

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
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let topLevelItems = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 1)

    let subLists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(subLists.count == 1)

    let subItems = findNodes(in: subLists[0], ofType: ListItemNode.self)
    #expect(subItems.count == 1)
    #expect(innerText(subItems[0]) == "b")

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
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let codeBlocks = findNodes(in: listItems[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "foo")

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "bar")

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
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let topLevelItems = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 1)

    // Top level item should have paragraph, sublist, and another paragraph
    let topParagraphs = findNodes(in: topLevelItems[0], ofType: ParagraphNode.self)
    #expect(topParagraphs.count == 2)
    #expect(innerText(topParagraphs[0]) == "foo")
    #expect(innerText(topParagraphs[1]) == "baz")

    let subLists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(subLists.count == 1)

    let subItems = findNodes(in: subLists[0], ofType: ListItemNode.self)
    #expect(subItems.count == 1)
    #expect(innerText(subItems[0]) == "bar")

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
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let topLevelItems = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 2)

    // First top-level item
    let firstItemParagraphs = findNodes(in: topLevelItems[0], ofType: ParagraphNode.self)
    #expect(firstItemParagraphs.count == 1)
    #expect(innerText(firstItemParagraphs[0]) == "a")

    let firstSubLists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(firstSubLists.count == 1)

    let firstSubItems = findNodes(in: firstSubLists[0], ofType: ListItemNode.self)
    #expect(firstSubItems.count == 2)
    #expect(innerText(firstSubItems[0]) == "b")
    #expect(innerText(firstSubItems[1]) == "c")

    // Second top-level item
    let secondItemParagraphs = findNodes(in: topLevelItems[1], ofType: ParagraphNode.self)
    #expect(secondItemParagraphs.count == 1)
    #expect(innerText(secondItemParagraphs[0]) == "d")

    let secondSubLists = findNodes(in: topLevelItems[1], ofType: UnorderedListNode.self)
    #expect(secondSubLists.count == 1)

    let secondSubItems = findNodes(in: secondSubLists[0], ofType: ListItemNode.self)
    #expect(secondSubItems.count == 2)
    #expect(innerText(secondSubItems[0]) == "e")
    #expect(innerText(secondSubItems[1]) == "f")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]],list_item[paragraph[text(\"d\")],unordered_list(level:2)[list_item[paragraph[text(\"e\")]],list_item[paragraph[text(\"f\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

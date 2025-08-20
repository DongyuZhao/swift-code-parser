import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Block Quotes Tests - Spec 024")
struct MarkdownBlockQuotesTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple block quote with heading and paragraph")
  func simpleBlockQuoteWithHeadingAndParagraph() {
    let input = """
    > # Foo
    > bar
    > baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let headers = findNodes(in: blockquotes[0], ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "Foo")

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "bar")
    #expect(textNodes[1].content == "baz")

    let expectedSig = "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quote with spaces after > characters omitted")
  func blockQuoteWithSpacesAfterAngleBracketCharactersOmitted() {
    let input = """
    ># Foo
    >bar
    > baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let headers = findNodes(in: blockquotes[0], ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "Foo")

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "bar")
    #expect(textNodes[1].content == "baz")

    let expectedSig = "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quote markers can be indented 1-3 spaces")
  func blockQuoteMarkersCanBeIndentedOneToThreeSpaces() {
    let input = """
       > # Foo
       > bar
     > baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let headers = findNodes(in: blockquotes[0], ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "Foo")

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "bar")
    #expect(textNodes[1].content == "baz")

    let expectedSig = "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation creates code block instead of block quote")
  func fourSpacesIndentationCreatesCodeBlockInsteadOfBlockQuote() {
    let input = """
        > # Foo
        > bar
        > baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should create code block, not block quote
    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 0)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "> # Foo\n> bar\n> baz")

    let expectedSig = "document[code_block(\"> # Foo\\n> bar\\n> baz\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lazy continuation allows omitting > before paragraph continuation")
  func lazyContinuationAllowsOmittingAngleBracketBeforeParagraphContinuation() {
    let input = """
    > # Foo
    > bar
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let headers = findNodes(in: blockquotes[0], ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "Foo")

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

  let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
  #expect(textNodes.count == 2)
  #expect(textNodes[0].content == "bar")
  #expect(textNodes[1].content == "baz")

  let expectedSig = "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quote with mixed lazy and non-lazy continuation lines")
  func blockQuoteWithMixedLazyAndNonLazyContinuationLines() {
    let input = """
    > bar
    baz
    > foo
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "bar")
    #expect(textNodes[1].content == "baz")
    #expect(textNodes[2].content == "foo")

    let expectedSig = "document[blockquote[paragraph[text(\"bar\"),text(\"baz\"),text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Laziness does not apply to setext heading underline")
  func lazinessDoesNotApplyToSetextHeadingUnderline() {
    let input = """
    > foo
    ---
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    let expectedSig = "document[blockquote[paragraph[text(\"foo\")]],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Laziness does not apply to list items")
  func lazinessDoesNotApplyToListItems() {
    let input = """
    > - foo
    - bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let listsInBlockquote = findNodes(in: blockquotes[0], ofType: UnorderedListNode.self)
    #expect(listsInBlockquote.count == 1)

    let itemsInBlockquote = findNodes(in: listsInBlockquote[0], ofType: ListItemNode.self)
    #expect(itemsInBlockquote.count == 1)
    #expect(innerText(itemsInBlockquote[0]) == "foo")

    let listsOutside = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(listsOutside.count == 2) // One inside blockquote, one outside

    let expectedSig = "document[blockquote[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Laziness does not apply to indented code blocks")
  func lazinessDoesNotApplyToIndentedCodeBlocks() {
    let input = """
    >     foo
        bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let codeBlocksInBlockquote = findNodes(in: blockquotes[0], ofType: CodeBlockNode.self)
    #expect(codeBlocksInBlockquote.count == 1)
    #expect(codeBlocksInBlockquote[0].source == "foo")

    let codeBlocksOutside = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocksOutside.count == 2) // One inside blockquote, one outside

    let expectedSig = "document[blockquote[code_block(\"foo\")],code_block(\"bar\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Laziness does not apply to fenced code blocks")
  func lazinessDoesNotApplyToFencedCodeBlocks() {
    let input = """
    > ```
    foo
    ```
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let codeBlocksInBlockquote = findNodes(in: blockquotes[0], ofType: CodeBlockNode.self)
    #expect(codeBlocksInBlockquote.count == 1)
    #expect(codeBlocksInBlockquote[0].source == "")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let codeBlocksOutside = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocksOutside.count == 2) // One inside blockquote, one outside

    let expectedSig = "document[blockquote[code_block(\"\")],paragraph[text(\"foo\")],code_block(\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lazy continuation line with indented content becomes paragraph text")
  func lazyContinuationLineWithIndentedContentBecomesParagraphText() {
    let input = """
    > foo
        - bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "foo")
    #expect(textNodes[1].content == "- bar")

    let expectedSig = "document[blockquote[paragraph[text(\"foo\"),text(\"- bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty block quote with single >")
  func emptyBlockQuoteWithSingleAngleBracket() {
    let input = ">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    // Empty block quote should have no content
    let children = blockquotes[0].children
    #expect(children.count == 0)

    let expectedSig = "document[blockquote[]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty block quote with multiple empty lines")
  func emptyBlockQuoteWithMultipleEmptyLines() {
    let input = """
    >
    >
    >
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    // Empty block quote should have no content
    let children = blockquotes[0].children
    #expect(children.count == 0)

    let expectedSig = "document[blockquote[]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quote with initial and final blank lines")
  func blockQuoteWithInitialAndFinalBlankLines() {
    let input = """
    >
    > foo
    >
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "foo")

    let expectedSig = "document[blockquote[paragraph[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank line separates block quotes into distinct quotes")
  func blankLineSeparatesBlockQuotesIntoDistinctQuotes() {
    let input = """
    > foo

    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 2)

    let paragraphs1 = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "foo")

    let paragraphs2 = findNodes(in: blockquotes[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "bar")

    let expectedSig = "document[blockquote[paragraph[text(\"foo\")]],blockquote[paragraph[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Consecutive block quotes without blank line form single quote")
  func consecutiveBlockQuotesWithoutBlankLineFormSingleQuote() {
    let input = """
    > foo
    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "foo")
    #expect(textNodes[1].content == "bar")

    let expectedSig = "document[blockquote[paragraph[text(\"foo\"),text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quote with two paragraphs using blank line separator")
  func blockQuoteWithTwoParagraphsUsingBlankLineSeparator() {
    let input = """
    > foo
    >
    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "foo")
    #expect(innerText(paragraphs[1]) == "bar")

    let expectedSig = "document[blockquote[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quotes can interrupt paragraphs")
  func blockQuotesCanInterruptParagraphs() {
    let input = """
    foo
    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2) // One outside, one inside blockquote

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphsInBlockquote = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphsInBlockquote.count == 1)
    #expect(innerText(paragraphsInBlockquote[0]) == "bar")

    let expectedSig = "document[paragraph[text(\"foo\")],blockquote[paragraph[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block quotes around thematic break without blank lines")
  func blockQuotesAroundThematicBreakWithoutBlankLines() {
    let input = """
    > aaa
    ***
    > bbb
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 2)

    let paragraphs1 = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs1.count == 1)
    #expect(innerText(paragraphs1[0]) == "aaa")

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    let paragraphs2 = findNodes(in: blockquotes[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "bbb")

    let expectedSig = "document[blockquote[paragraph[text(\"aaa\")]],thematic_break,blockquote[paragraph[text(\"bbb\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lazy continuation without blank line includes following paragraph")
  func lazyContinuationWithoutBlankLineIncludesFollowingParagraph() {
    let input = """
    > bar
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "bar")
    #expect(textNodes[1].content == "baz")

    let expectedSig = "document[blockquote[paragraph[text(\"bar\"),text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank line after block quote separates from following paragraph")
  func blankLineAfterBlockQuoteSeparatesFromFollowingParagraph() {
    let input = """
    > bar

    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphsInBlockquote = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphsInBlockquote.count == 1)
    #expect(innerText(paragraphsInBlockquote[0]) == "bar")

    let allParagraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(allParagraphs.count == 2)

    let expectedSig = "document[blockquote[paragraph[text(\"bar\")]],paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty line in block quote separates from following paragraph")
  func emptyLineInBlockQuoteSeparatesFromFollowingParagraph() {
    let input = """
    > bar
    >
    baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphsInBlockquote = findNodes(in: blockquotes[0], ofType: ParagraphNode.self)
    #expect(paragraphsInBlockquote.count == 1)
    #expect(innerText(paragraphsInBlockquote[0]) == "bar")

    let allParagraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(allParagraphs.count == 2)

    let expectedSig = "document[blockquote[paragraph[text(\"bar\")]],paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested block quotes with lazy continuation")
  func nestedBlockQuotesWithLazyContinuation() {
    let input = """
    > > > foo
    bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let outerBlockquote = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(outerBlockquote.count == 1)

    let middleBlockquote = findNodes(in: outerBlockquote[0], ofType: BlockquoteNode.self)
    #expect(middleBlockquote.count == 1)

    let innerBlockquote = findNodes(in: middleBlockquote[0], ofType: BlockquoteNode.self)
    #expect(innerBlockquote.count == 1)

    let paragraphs = findNodes(in: innerBlockquote[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "foo")
    #expect(textNodes[1].content == "bar")

    let expectedSig = "document[blockquote[blockquote[blockquote[paragraph[text(\"foo\"),text(\"bar\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested block quotes with mixed continuation markers")
  func nestedBlockQuotesWithMixedContinuationMarkers() {
    let input = """
    >>> foo
    > bar
    >>baz
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let outerBlockquote = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(outerBlockquote.count == 1)

    let middleBlockquote = findNodes(in: outerBlockquote[0], ofType: BlockquoteNode.self)
    #expect(middleBlockquote.count == 1)

    let innerBlockquote = findNodes(in: middleBlockquote[0], ofType: BlockquoteNode.self)
    #expect(innerBlockquote.count == 1)

    let paragraphs = findNodes(in: innerBlockquote[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "foo")
    #expect(textNodes[1].content == "bar")
    #expect(textNodes[2].content == "baz")

    let expectedSig = "document[blockquote[blockquote[blockquote[paragraph[text(\"foo\"),text(\"bar\"),text(\"baz\")]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented code block in block quote requires five spaces after >")
  func indentedCodeBlockInBlockQuoteRequiresFiveSpacesAfterAngleBracket() {
    let input = """
    >     code

    >    not code
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 2)

    // First blockquote should contain code block
    let codeBlocks = findNodes(in: blockquotes[0], ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "code")

    // Second blockquote should contain paragraph (not code)
    let paragraphs = findNodes(in: blockquotes[1], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "not code")

    let expectedSig = "document[blockquote[code_block(\"code\")],blockquote[paragraph[text(\"not code\")]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

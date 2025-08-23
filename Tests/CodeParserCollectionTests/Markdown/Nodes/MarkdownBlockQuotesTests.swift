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

    // Should create code block, not block quote

    let expectedSig = "document[code_block(\"> # Foo\n> bar\n> baz\")]"
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

    let expectedSig = "document[blockquote[paragraph[text(\"foo\"),text(\"- bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty block quote with single >")
  func emptyBlockQuoteWithSingleAngleBracket() {
    let input = ">"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[blockquote]"
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

    let expectedSig = "document[blockquote]"
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

    // First blockquote should contain code block

    // Second blockquote should contain paragraph (not code)

    let expectedSig = "document[blockquote[code_block(\"code\")],blockquote[paragraph[text(\"not code\")]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Paragraphs Tests - Spec 021")
struct MarkdownParagraphsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Two simple paragraphs separated by blank line")
  func twoSimpleParagraphsSeparatedByBlankLine() {
    let input = """
    aaa

    bbb
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"aaa\")],paragraph[text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraphs can contain multiple lines but no blank lines")
  func paragraphsCanContainMultipleLinesButNoBlankLines() {
    let input = """
    aaa
    bbb

    ccc
    ddd
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")],paragraph[text(\"ccc\"),line_break(soft),text(\"ddd\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple blank lines between paragraphs have no effect")
  func multipleBlankLinesBetweenParagraphsHaveNoEffect() {
    let input = """
    aaa

    bbb
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"aaa\")],paragraph[text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Leading spaces are skipped in paragraphs")
  func leadingSpacesAreSkippedInParagraphs() {
    let input = """
      aaa
     bbb
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Lines after first may be indented any amount in paragraphs")
  func linesAfterFirstMayBeIndentedAnyAmountInParagraphs() {
    let input = """
    aaa
                 bbb
                                           ccc
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\"),line_break(soft),text(\"ccc\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First line may be indented at most three spaces")
  func firstLineMayBeIndentedAtMostThreeSpaces() {
    let input = """
       aaa
    bbb
    """
    let result = parser.parse(input, language: language)

    // Should not create a code block

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation triggers code block instead of paragraph")
  func fourSpacesIndentationTriggersCodeBlockInsteadOfParagraph() {
    let input = """
        aaa
    bbb
    """
    let result = parser.parse(input, language: language)

    // Should create a code block and a paragraph

    let expectedSig = "document[code_block(\"aaa\"),paragraph[text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph ending with two spaces creates hard line break")
  func paragraphEndingWithTwoSpacesCreatesHardLineBreak() {
    let input = "aaa  \nbbb"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"aaa\"),line_break(hard),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with single line containing only whitespace creates empty paragraph")
  func paragraphWithSingleLineContainingOnlyWhitespaceCreatesEmptyParagraph() {
    let input = "   "
    let result = parser.parse(input, language: language)

    // Leading and trailing whitespace should be removed, creating no content

    let expectedSig = "document"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with mixed indentation preserves content structure")
  func paragraphWithMixedIndentationPreservesContentStructure() {
    let input = """
    aaa
      bbb
    ccc
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\"),text(\"ccc\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty lines separate paragraphs regardless of surrounding content")
  func emptyLinesSeparateParagraphsRegardlessOfSurroundingContent() {
    let input = """
    first paragraph

    second paragraph

    third paragraph
    """
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"first paragraph\")],paragraph[text(\"second paragraph\")],paragraph[text(\"third paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with trailing spaces followed by newline without line break")
  func paragraphWithTrailingSpacesFollowedByNewlineWithoutLineBreak() {
    let input = "aaa \nbbb"
    let result = parser.parse(input, language: language)

  // Single trailing space should not create hard line break, but newline is a soft break

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph content preserves internal structure with inline elements")
  func paragraphContentPreservesInternalStructureWithInlineElements() {
    let input = """
    This is a paragraph
    with multiple lines
    and some content.
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"This is a paragraph\"),line_break(soft),text(\"with multiple lines\"),line_break(soft),text(\"and some content.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single line paragraph without trailing newline")
  func singleLineParagraphWithoutTrailingNewline() {
    let input = "single line"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"single line\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with maximum allowed indentation on first line")
  func paragraphWithMaximumAllowedIndentationOnFirstLine() {
    let input = """
       aaa
       bbb
       ccc
    """
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\"),line_break(soft),text(\"ccc\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

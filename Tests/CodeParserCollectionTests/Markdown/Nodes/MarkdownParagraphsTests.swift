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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    #expect(innerText(paragraphs[0]) == "aaa")
    #expect(innerText(paragraphs[1]) == "bbb")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let textNodes1 = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes1.count == 2)
    #expect(textNodes1[0].content == "aaa")
    #expect(textNodes1[1].content == "bbb")

    let textNodes2 = findNodes(in: paragraphs[1], ofType: TextNode.self)
    #expect(textNodes2.count == 2)
    #expect(textNodes2[0].content == "ccc")
    #expect(textNodes2[1].content == "ddd")

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\")],paragraph[text(\"ccc\"),text(\"ddd\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple blank lines between paragraphs have no effect")
  func multipleBlankLinesBetweenParagraphsHaveNoEffect() {
    let input = """
    aaa


    bbb
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    #expect(innerText(paragraphs[0]) == "aaa")
    #expect(innerText(paragraphs[1]) == "bbb")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\")]]"
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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")
    #expect(textNodes[2].content == "ccc")

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\"),text(\"ccc\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First line may be indented at most three spaces")
  func firstLineMayBeIndentedAtMostThreeSpaces() {
    let input = """
       aaa
    bbb
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")

    // Should not create a code block
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation triggers code block instead of paragraph")
  func fourSpacesIndentationTriggersCodeBlockInsteadOfParagraph() {
    let input = """
        aaa
    bbb
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should create a code block and a paragraph
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "aaa")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "bbb")

    let expectedSig = "document[code_block(\"aaa\"),paragraph[text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph ending with two spaces creates hard line break")
  func paragraphEndingWithTwoSpacesCreatesHardLineBreak() {
    let input = "aaa  \nbbb"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let children = paragraphs[0].children
    #expect(children.count == 3)

    // Should have text, line break, text
    let textNode1 = children[0] as? TextNode
    #expect(textNode1?.content == "aaa")

    let lineBreak = children[1] as? LineBreakNode
    #expect(lineBreak?.variant == .hard)

    let textNode2 = children[2] as? TextNode
    #expect(textNode2?.content == "bbb")

    let expectedSig = "document[paragraph[text(\"aaa\"),line_break(hard),text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with single line containing only whitespace creates empty paragraph")
  func paragraphWithSingleLineContainingOnlyWhitespaceCreatesEmptyParagraph() {
    let input = "   "
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Leading and trailing whitespace should be removed, creating no content
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 0)

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")
    #expect(textNodes[2].content == "ccc")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 3)

    #expect(innerText(paragraphs[0]) == "first paragraph")
    #expect(innerText(paragraphs[1]) == "second paragraph")
    #expect(innerText(paragraphs[2]) == "third paragraph")

    let expectedSig = "document[paragraph[text(\"first paragraph\")],paragraph[text(\"second paragraph\")],paragraph[text(\"third paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Paragraph with trailing spaces followed by newline without line break")
  func paragraphWithTrailingSpacesFollowedByNewlineWithoutLineBreak() {
    let input = "aaa \nbbb"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Single trailing space should not create hard line break
    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")

    // Should not have line break nodes
    let lineBreaks = findNodes(in: paragraphs[0], ofType: LineBreakNode.self)
    #expect(lineBreaks.count == 0)

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\")]]"
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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "This is a paragraph")
    #expect(textNodes[1].content == "with multiple lines")
    #expect(textNodes[2].content == "and some content.")

    let expectedSig = "document[paragraph[text(\"This is a paragraph\"),text(\"with multiple lines\"),text(\"and some content.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single line paragraph without trailing newline")
  func singleLineParagraphWithoutTrailingNewline() {
    let input = "single line"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    #expect(innerText(paragraphs[0]) == "single line")

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
    #expect(result.errors.isEmpty)

    // Three spaces indentation should still create paragraph
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "aaa")
    #expect(textNodes[1].content == "bbb")
    #expect(textNodes[2].content == "ccc")

    // Should not create code block
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let expectedSig = "document[paragraph[text(\"aaa\"),text(\"bbb\"),text(\"ccc\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

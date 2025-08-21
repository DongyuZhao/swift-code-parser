import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Indented Code Blocks Tests - Spec 017")
struct MarkdownIndentedCodeBlocksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple indented code block with four spaces")
  func simpleIndentedCodeBlock() {
    let input = "    a simple\n      indented code block"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "a simple\n  indented code block")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"a simple\\n  indented code block\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item interpretation takes precedence over code block")
  func listItemPrecedenceOverCodeBlock() {
    let input = "  - foo\n\n    bar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: result.root, ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested list with indented code in ordered list")
  func nestedListWithIndentedCode() {
    let input = "1.  foo\n\n    - bar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code block contains literal text without markdown parsing")
  func literalTextInCodeBlock() {
    let input = "    <a/>\n    *hi*\n\n    - one"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "<a/>\n*hi*\n\n- one")

    // Verify no inline parsing occurred
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 0)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"<a/>\\n*hi*\\n\\n- one\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Three chunks separated by blank lines")
  func threeChunksSeparatedByBlankLines() {
    let input = "    chunk1\n\n    chunk2\n\n\n\n    chunk3"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "chunk1\n\nchunk2\n\n\n\nchunk3")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"chunk1\\n\\nchunk2\\n\\n\\n\\nchunk3\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Extra spaces beyond four are preserved")
  func extraSpacesPreserved() {
    let input = "    chunk1\n\n      chunk2"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "chunk1\n\n  chunk2")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"chunk1\\n\\n  chunk2\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented code block cannot interrupt paragraph")
  func cannotInterruptParagraph() {
    let input = "Foo\n    bar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

  // Verify AST structure using sig
  let expectedSig = "document[paragraph[text(\"Foo\"),line_break(soft),text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Non-blank line with fewer than four spaces ends code block")
  func fewerSpacesEndsCodeBlock() {
    let input = "    foo\nbar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "foo")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"foo\"),paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented code can occur before and after other blocks")
  func codeBlocksBetweenOtherBlocks() {
    let input = "# Heading\n    foo\nHeading\n------\n    foo\n----"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 2)
    #expect(codeBlocks[0].source == "foo")
    #expect(codeBlocks[1].source == "foo")

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 1)
    #expect(headers[1].level == 2)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"Heading\")],code_block(\"foo\"),heading(level:2)[text(\"Heading\")],code_block(\"foo\"),thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First line can be indented more than four spaces")
  func firstLineMoreThanFourSpaces() {
    let input = "        foo\n    bar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "    foo\nbar")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"    foo\\nbar\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines before and after code block are not included")
  func blankLinesNotIncluded() {
    let input = "\n\n    foo\n\n"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "foo")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"foo\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Trailing spaces are included in code block content")
  func trailingSpacesIncluded() {
    let input = "    foo  "
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "foo  ")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"foo  \")]"
    #expect(sig(result.root) == expectedSig)
  }
}

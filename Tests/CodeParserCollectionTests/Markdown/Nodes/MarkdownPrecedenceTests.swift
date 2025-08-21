import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Precedence Tests - Spec 008")
struct MarkdownPrecedenceTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Block structure indicators take precedence over inline structure indicators")
  func blockStructurePrecedenceOverInline() {
    let input = """
    - `one
    - two`
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Find the unordered list
    let lists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(lists.count == 1)

    // Find list items
    let listItems = findNodes(in: result.root, ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // Verify that the backticks are treated as literal text, not code spans
    let codeNodes = findNodes(in: result.root, ofType: CodeSpanNode.self)
    #expect(codeNodes.count == 0, "No inline code nodes should be found as block structure takes precedence")

    // Verify text content
    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "`one")
    #expect(textNodes[1].content == "two`")

    // Verify AST structure using sig - should be two separate list items with text content
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"`one\")]],list_item[paragraph[text(\"two`\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Precedence allows two-step parsing: block structure first, then inline structure")
  func twoStepParsingSequence() {
    let input = """
    # Heading with *emphasis*

    - List item with `code`
    - Another item

    Regular paragraph with **strong** text.
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Verify block structure elements are present
    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 1)

    let lists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(lists.count == 1)

    let listItems = findNodes(in: result.root, ofType: ListItemNode.self)
    #expect(listItems.count == 2)

  let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
  #expect(paragraphs.count == 3) // Two in list items + one standalone

    // Verify inline structure elements are also present within blocks
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)

    let strongNodes = findNodes(in: result.root, ofType: StrongNode.self)
    #expect(strongNodes.count == 1)

    let codeNodes = findNodes(in: result.root, ofType: CodeSpanNode.self)
    #expect(codeNodes.count == 1)

    // Verify AST structure reflects proper precedence
    let expectedSig = """
    document[heading(level:1)[text("Heading with "),emphasis[text("emphasis")]],unordered_list(level:1)[list_item[paragraph[text("List item with "),code("code")]],list_item[paragraph[text("Another item")]]],paragraph[text("Regular paragraph with "),strong[text("strong")],text(" text.")]]
    """
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Block structure parsing processes lines sequentially")
  func sequentialBlockStructureParsing() {
    let input = """
    > Blockquote line 1
    > Blockquote line 2

    Regular paragraph
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Verify blockquote is properly formed with sequential line processing
    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2) // One inside blockquote, one standalone

    // Verify the blockquote contains the expected content
    let blockquoteTexts = findNodes(in: blockquotes.first!, ofType: TextNode.self)
    let blockquoteContent = blockquoteTexts.map { $0.content }.joined(separator: " ")
    #expect(blockquoteContent.contains("Blockquote line 1"))
    #expect(blockquoteContent.contains("Blockquote line 2"))

    // Verify AST structure
  let expectedSig = "document[blockquote[paragraph[text(\"Blockquote line 1\"),line_break(soft),text(\"Blockquote line 2\")]],paragraph[text(\"Regular paragraph\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Inline parsing within blocks does not affect other blocks")
  func independentInlineParsing() {
    let input = """
    Paragraph with *emphasis* and **strong**.

    Another paragraph with `code` and [link](url).
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Verify that each paragraph has its own inline elements
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // First paragraph should have emphasis and strong
    let firstParagraphEmphasis = findNodes(in: paragraphs[0], ofType: EmphasisNode.self)
    let firstParagraphStrong = findNodes(in: paragraphs[0], ofType: StrongNode.self)
    #expect(firstParagraphEmphasis.count == 1)
    #expect(firstParagraphStrong.count == 1)

    // Second paragraph should have code and link
    let secondParagraphCode = findNodes(in: paragraphs[1], ofType: CodeSpanNode.self)
    let secondParagraphLinks = findNodes(in: paragraphs[1], ofType: LinkNode.self)
    #expect(secondParagraphCode.count == 1)
    #expect(secondParagraphLinks.count == 1)

    // Verify inline elements are isolated to their respective paragraphs
    let firstParagraphCode = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    let firstParagraphLinks = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(firstParagraphCode.count == 0)
    #expect(firstParagraphLinks.count == 0)

    let secondParagraphEmphasis = findNodes(in: paragraphs[1], ofType: EmphasisNode.self)
    let secondParagraphStrong = findNodes(in: paragraphs[1], ofType: StrongNode.self)
    #expect(secondParagraphEmphasis.count == 0)
    #expect(secondParagraphStrong.count == 0)

    // Verify AST structure shows independent inline parsing
    let expectedSig = "document[paragraph[text(\"Paragraph with \"),emphasis[text(\"emphasis\")],text(\" and \"),strong[text(\"strong\")],text(\".\")],paragraph[text(\"Another paragraph with \"),code(\"code\"),text(\" and \"),link(url:\"url\",title:\"\")[text(\"link\")],text(\".\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

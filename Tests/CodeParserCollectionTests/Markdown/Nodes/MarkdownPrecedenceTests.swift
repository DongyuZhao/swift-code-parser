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

    // Verify block structure elements are present

    // Verify inline structure elements are also present within blocks

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

    // Verify blockquote is properly formed with sequential line processing

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

    // Verify that each paragraph has its own inline elements

    // First paragraph should have emphasis and strong

    // Second paragraph should have code and link

    // Verify inline elements are isolated to their respective paragraphs

    // Verify AST structure shows independent inline parsing
    let expectedSig = "document[paragraph[text(\"Paragraph with \"),emphasis[text(\"emphasis\")],text(\" and \"),strong[text(\"strong\")],text(\".\")],paragraph[text(\"Another paragraph with \"),code(\"code\"),text(\" and \"),link(url:\"url\",title:\"\")[text(\"link\")],text(\".\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

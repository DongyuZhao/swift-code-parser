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
    let input = #"""
          a simple
            indented code block
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("a simple\#n  indented code block\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("List item interpretation takes precedence over code block")
  func listItemPrecedenceOverCodeBlock() {
    let input = #"""
        - foo

          bar
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      #"document[unordered_list(level:1)[list_item[paragraph[text("foo")],paragraph[text("bar")]]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested list with indented code in ordered list")
  func nestedListWithIndentedCode() {
    let input = #"""
      1.  foo

          - bar
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      #"document[ordered_list(level:1)[list_item[paragraph[text("foo")],unordered_list(level:2)[list_item[paragraph[text("bar")]]]]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code block contains literal text without markdown parsing")
  func literalTextInCodeBlock() {
    let input = #"""
          <a/>
          *hi*

          - one
      """#
    let result = parser.parse(input, language: language)

    // Verify no inline parsing occurred

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("<a/>\#n*hi*\#n\#n- one\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Three chunks separated by blank lines")
  func threeChunksSeparatedByBlankLines() {
    let input = #"""
          chunk1

          chunk2



          chunk3
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("chunk1\#n\#nchunk2\#n\#n\#n\#nchunk3\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Extra spaces beyond four are preserved")
  func extraSpacesPreserved() {
    let input = #"""
          chunk1

            chunk2
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("chunk1\#n\#n  chunk2\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented code block cannot interrupt paragraph")
  func cannotInterruptParagraph() {
    let input = #"""
      Foo
          bar
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[paragraph[text("Foo"),line_break(soft),text("bar")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Non-blank line with fewer than four spaces ends code block")
  func fewerSpacesEndsCodeBlock() {
    let input = #"""
          foo
      bar
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("foo\#n"),paragraph[text("bar")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented code can occur before and after other blocks")
  func codeBlocksBetweenOtherBlocks() {
    let input = #"""
      # Heading
          foo
      Heading
      ------
          foo
      ----
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      #"document[heading(level:1)[text("Heading")],code_block("foo\#n"),heading(level:2)[text("Heading")],code_block("foo\#n"),thematic_break]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First line can be indented more than four spaces")
  func firstLineMoreThanFourSpaces() {
    let input = #"""
              foo
          bar
      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("    foo\#nbar\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Blank lines before and after code block are not included")
  func blankLinesNotIncluded() {
    let input = #"""


          foo


      """#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("foo\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Trailing spaces are included in code block content")
  func trailingSpacesIncluded() {
    let input = #"    foo  "#
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = #"document[code_block("foo  \#n")]"#
    #expect(sig(result.root) == expectedSig)
  }
}

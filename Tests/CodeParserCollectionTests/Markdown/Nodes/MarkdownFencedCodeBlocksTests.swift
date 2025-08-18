import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Fenced Code Blocks Tests - Spec 018")
struct MarkdownFencedCodeBlocksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple backtick fenced code block")
  func simpleBacktickFencedCodeBlock() {
    let input = "```\n<\n >\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "<\n >")
    #expect(codeBlocks.first?.language == nil)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"<\\n >\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Simple tilde fenced code block")
  func simpleTildeFencedCodeBlock() {
    let input = "~~~\n<\n >\n~~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "<\n >")
    #expect(codeBlocks.first?.language == nil)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"<\\n >\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Fewer than three backticks is not enough")
  func fewerThanThreeBackticks() {
    let input = "``\nfoo\n``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let inlineCodes = findNodes(in: result.root, ofType: CodeSpanNode.self)
    #expect(inlineCodes.count == 1)
    #expect(inlineCodes.first?.code == "foo")

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[code(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing fence must use same character as opening")
  func closingFenceMustMatchOpening() {
    let input = "```\naaa\n~~~\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n~~~")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n~~~\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tilde fence cannot be closed by backticks")
  func tildeFenceNotClosedByBackticks() {
    let input = "~~~\naaa\n```\n~~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n```")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n```\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing fence must be at least as long as opening")
  func closingFenceMustBeLongEnough() {
    let input = "````\naaa\n```\n``````"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n```")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n```\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tilde fence requires matching length")
  func tildeFenceRequiresMatchingLength() {
    let input = "~~~~\naaa\n~~~\n~~~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n~~~")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n~~~\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unclosed code block at end of document")
  func unclosedCodeBlockAtEndOfDocument() {
    let input = "```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unclosed code block with content")
  func unclosedCodeBlockWithContent() {
    let input = "`````\n\n```\naaa"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\n```\naaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\\n```\\naaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unclosed code block in blockquote")
  func unclosedCodeBlockInBlockquote() {
    let input = "> ```\n> aaa\n\nbbb"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[blockquote[code_block(\"aaa\")],paragraph[text(\"bbb\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code block can have all empty lines")
  func codeBlockAllEmptyLines() {
    let input = "```\n\n\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\n")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\\n\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code block can be empty")
  func emptyCodeBlock() {
    let input = "```\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Indented fence with equivalent indentation removed")
  func indentedFenceWithIndentationRemoved() {
    let input = " ```\n aaa\naaa\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\naaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\naaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Two space indented fence")
  func twoSpaceIndentedFence() {
    let input = "  ```\naaa\n  aaa\naaa\n  ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\naaa\naaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\naaa\\naaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Three space indented fence with varied content indentation")
  func threeSpaceIndentedFence() {
    let input = "   ```\n   aaa\n    aaa\n  aaa\n   ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n aaa\naaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n aaa\\naaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces creates indented code block not fenced")
  func fourSpacesCreatesIndentedCodeBlock() {
    let input = "    ```\n    aaa\n    ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "```\naaa\n```")
    #expect(codeBlocks.first?.language == nil)

    // Verify AST structure using sig (this should be an indented code block)
    let expectedSig = "document[code_block(\"```\\naaa\\n```\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing fence can be indented differently")
  func closingFenceCanBeIndentedDifferently() {
    let input = "```\naaa\n  ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Three space indented opening with two space closing")
  func mixedIndentationOpeningAndClosing() {
    let input = "   ```\naaa\n  ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four space indented closing fence is not recognized")
  func fourSpaceIndentedClosingNotRecognized() {
    let input = "```\naaa\n    ```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n    ```")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n    ```\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code fences cannot contain internal spaces")
  func codeFencesCannotContainSpaces() {
    let input = "``` ```\naaa"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let inlineCodes = findNodes(in: result.root, ofType: CodeSpanNode.self)
    #expect(inlineCodes.count == 1)
    #expect(inlineCodes.first?.code == " ")

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[code(\" \"),text(\"\\naaa\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tilde fence with spaces in closing")
  func tildeFenceWithSpacesInClosing() {
    let input = "~~~~~~\naaa\n~~~ ~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "aaa\n~~~ ~~")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"aaa\\n~~~ ~~\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Fenced code blocks can interrupt paragraphs")
  func fencedCodeCanInterruptParagraphs() {
    let input = "foo\n```\nbar\n```\nbaz"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "bar")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo\")],code_block(\"bar\"),paragraph[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Other blocks can occur before and after fenced code")
  func otherBlocksAroundFencedCode() {
    let input = "foo\n---\n~~~\nbar\n~~~\n# baz"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 2) // Setext heading
    #expect(headers[1].level == 1) // ATX heading

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "bar")

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"foo\")],code_block(\"bar\"),heading(level:1)[text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Info string with language specification")
  func infoStringWithLanguage() {
    let input = "```ruby\ndef foo(x)\n  return 3\nend\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.language == "ruby")
    #expect(codeBlocks.first?.source == "def foo(x)\n  return 3\nend")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(lang:\"ruby\",\"def foo(x)\\n  return 3\\nend\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Info string with additional metadata")
  func infoStringWithMetadata() {
    let input = "~~~~    ruby startline=3 $%@#$\ndef foo(x)\n  return 3\nend\n~~~~~~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.language == "ruby")
    #expect(codeBlocks.first?.source == "def foo(x)\n  return 3\nend")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(lang:\"ruby\",\"def foo(x)\\n  return 3\\nend\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Info string with semicolon")
  func infoStringWithSemicolon() {
    let input = "```;\n````"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.language == ";")
    #expect(codeBlocks.first?.source == "")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(lang:\";\",\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backtick info string cannot contain backticks")
  func backtickInfoStringCannotContainBackticks() {
    let input = "``` aa ```\nfoo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let inlineCodes = findNodes(in: result.root, ofType: CodeSpanNode.self)
    #expect(inlineCodes.count == 1)
    #expect(inlineCodes.first?.code == "aa")

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[code(\"aa\"),text(\"\\nfoo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tilde info string can contain backticks and tildes")
  func tildeInfoStringCanContainBackticksAndTildes() {
    let input = "~~~ aa ``` ~~~\nfoo\n~~~"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.language == "aa")
    #expect(codeBlocks.first?.source == "foo")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(lang:\"aa\",\"foo\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing fences cannot have info strings")
  func closingFencesCannotHaveInfoStrings() {
    let input = "```\n``` aaa\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "``` aaa")

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"``` aaa\")]"
    #expect(sig(result.root) == expectedSig)
  }
}

import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Thematic Breaks Tests - Spec 010")
struct MarkdownThematicBreaksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Valid thematic breaks with three matching characters")
  func basicThematicBreaks() {
    let input = "***\n---\n___"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break,thematic_break,thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid characters for thematic breaks")
  func wrongCharacters() {
    let input = "+++"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"+++\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Equals signs are not valid thematic break characters")
  func equalsNotValid() {
    let input = "==="
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"===\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Not enough characters for thematic break")
  func notEnoughCharacters() {
    let input = "--\n**\n__"
    let result = parser.parse(input, language: language)

  // Verify AST structure using sig
  let expectedSig = "document[paragraph[text(\"--\"),line_break(soft),text(\"**\"),line_break(soft),text(\"__\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("One to three spaces indentation allowed")
  func validIndentation() {
    let input = " ***\n  ***\n   ***"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break,thematic_break,thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation creates code block instead")
  func fourSpacesCodeBlock() {
    let input = "    ***"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"***\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces after text creates paragraph")
  func fourSpacesAfterText() {
    let input = "Foo\n    ***"
    let result = parser.parse(input, language: language)

  // Verify AST structure using sig: newline inside paragraph is a soft break
  let expectedSig = "document[paragraph[text(\"Foo\"),line_break(soft),text(\"***\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("More than three characters allowed")
  func moreCharactersAllowed() {
    let input = "_____________________________________"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Spaces between characters allowed")
  func spaceBetweenCharacters() {
    let input = " - - -"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Spaces between asterisks allowed")
  func spaceBetweenAsterisks() {
    let input = " **  * ** * ** * **"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple spaces between characters allowed")
  func multipleSpacesBetweenCharacters() {
    let input = "-     -      -      -"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Spaces at end allowed")
  func spacesAtEndAllowed() {
    let input = "- - - -    "
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Other characters in line not allowed")
  func otherCharactersNotAllowed() {
    let input = "_ _ _ _ a\n\na------\n\n---a---"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"_ _ _ _ a\")],paragraph[text(\"a------\")],paragraph[text(\"---a---\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed characters not allowed")
  func mixedCharactersNotAllowed() {
    let input = " *-*"
    let result = parser.parse(input, language: language)

    // Should parse as emphasis around dash

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[emphasis[text(\"-\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Thematic breaks without blank lines before or after")
  func noBlankLinesRequired() {
    let input = "- foo\n***\n- bar"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],thematic_break,unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Thematic break can interrupt paragraph")
  func canInterruptParagraph() {
    let input = "Foo\n***\nbar"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo\")],thematic_break,paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Setext heading takes precedence over thematic break")
  func setextHeadingPrecedence() {
    let input = "Foo\n---\nbar"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"Foo\")],paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Thematic break takes precedence over list item")
  func thematicBreakPrecedenceOverList() {
    let input = "* Foo\n* * *\n* Bar"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]]],thematic_break,unordered_list(level:1)[list_item[paragraph[text(\"Bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Thematic break inside list item with different bullet")
  func thematicBreakInListItem() {
    let input = "- Foo\n- * * *"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]],list_item[thematic_break]]]"
    #expect(sig(result.root) == expectedSig)
  }
}

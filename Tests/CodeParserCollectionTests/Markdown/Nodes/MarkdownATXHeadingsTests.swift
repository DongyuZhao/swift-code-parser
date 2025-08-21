import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown ATX Headings Tests - Spec 011")
struct MarkdownATXHeadingsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple headings with levels 1 through 6")
  func simpleHeadingLevels() {
    let input = """
      # foo
      ## foo
      ### foo
      #### foo
      ##### foo
      ###### foo
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      "document[heading(level:1)[text(\"foo\")],heading(level:2)[text(\"foo\")],heading(level:3)[text(\"foo\")],heading(level:4)[text(\"foo\")],heading(level:5)[text(\"foo\")],heading(level:6)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("More than six hash characters creates paragraph, not heading")
  func moreThanSixHashesCreatesParagraph() {
    let input = "####### foo"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"####### foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hash characters require space or end of line after them")
  func hashCharactersRequireSpaceOrEOL() {
    let input = """
      #5 bolt

      #hashtag
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"#5 bolt\")],paragraph[text(\"#hashtag\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Escaped hash character does not create heading")
  func escapedHashNotHeading() {
    let input = "\\## foo"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"## foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Contents are parsed as inline elements")
  func contentsAreInlineElements() {
    let input = "# foo *bar* \\*baz\\*"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      "document[heading(level:1)[text(\"foo \"),emphasis[text(\"bar\")],text(\" *baz*\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Leading and trailing whitespace is ignored in content")
  func whitespaceIgnoredInContent() {
    let input = "#                  foo"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("One to three spaces indentation allowed")
  func oneToThreeSpacesIndentationAllowed() {
    let input = """
       ### foo
        ## foo
         # foo
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      "document[heading(level:3)[text(\"foo\")],heading(level:2)[text(\"foo\")],heading(level:1)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation creates code block")
  func fourSpacesCreateCodeBlock() {
    let input = "    # foo"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"# foo\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces after text content creates paragraph")
  func fourSpacesAfterTextCreatesParagraph() {
    let input = """
      foo
          # bar
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig: newline inside paragraph is a soft break
    let expectedSig = "document[paragraph[text(\"foo\"),line_break(soft),text(\"# bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Optional closing sequence of hash characters")
  func optionalClosingSequence() {
    let input = """
      ## foo ##
        ###   bar    ###
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2)[text(\"foo\")],heading(level:3)[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing sequence need not match opening sequence length")
  func closingSequenceNeedNotMatchOpening() {
    let input = """
      # foo ##################################
      ##### foo ##
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo\")],heading(level:5)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Spaces allowed after closing sequence")
  func spacesAllowedAfterClosingSequence() {
    let input = "### foo ###     "
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hash characters with non-spaces become part of content")
  func hashCharactersWithNonSpacesBecomeContent() {
    let input = "### foo ### b"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo ### b\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing sequence must be preceded by space")
  func closingSequenceMustBePrecededBySpace() {
    let input = "# foo#"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo#\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash-escaped hash characters do not count in closing sequence")
  func escapedHashDoNotCountInClosingSequence() {
    let input = """
      ### foo \\###
      ## foo #\\##
      # foo \\#
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig =
      "document[heading(level:3)[text(\"foo ###\")],heading(level:2)[text(\"foo ###\")],heading(level:1)[text(\"foo #\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("ATX headings can be surrounded by thematic breaks without blank lines")
  func headingsSurroundedByThematicBreaks() {
    let input = """
      ****
      ## foo
      ****
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break,heading(level:2)[text(\"foo\")],thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("ATX headings can interrupt paragraphs")
  func headingsCanInterruptParagraphs() {
    let input = """
      Foo bar
      # baz
      Bar foo
      """
    let result = parser.parse(input, language: language)
    // Verify AST structure using sig
    let expectedSig =
      "document[paragraph[text(\"Foo bar\")],heading(level:1)[text(\"baz\")],paragraph[text(\"Bar foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("ATX headings can be empty")
  func headingsCanBeEmpty() {
    let input = """
      ##
      #
      ### ###
      """
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2),heading(level:1),heading(level:3)]"
    #expect(sig(result.root) == expectedSig)
  }
}

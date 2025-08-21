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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 6)

    // Verify each heading level
    for (index, header) in headers.enumerated() {
      #expect(header.level == index + 1)
      let text = findNodes(in: header, ofType: TextNode.self).map { $0.content }.joined()
      #expect(text == "foo")
    }

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo\")],heading(level:2)[text(\"foo\")],heading(level:3)[text(\"foo\")],heading(level:4)[text(\"foo\")],heading(level:5)[text(\"foo\")],heading(level:6)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("More than six hash characters creates paragraph, not heading")
  func moreThanSixHashesCreatesParagraph() {
    let input = "####### foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"#5 bolt\")],paragraph[text(\"#hashtag\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Escaped hash character does not create heading")
  func escapedHashNotHeading() {
    let input = "\\## foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"## foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Contents are parsed as inline elements")
  func contentsAreInlineElements() {
    let input = "# foo *bar* \\*baz\\*"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 1)

    let emphasisNodes = findNodes(in: headers.first!, ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo \"),emphasis[text(\"bar\")],text(\" *baz*\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Leading and trailing whitespace is ignored in content")
  func whitespaceIgnoredInContent() {
    let input = "#                  foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 1)

    let text = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "foo")

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 3)
    #expect(headers[0].level == 3)
    #expect(headers[1].level == 2)
    #expect(headers[2].level == 1)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo\")],heading(level:2)[text(\"foo\")],heading(level:1)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Four spaces indentation creates code block")
  func fourSpacesCreateCodeBlock() {
    let input = "    # foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "# foo")

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 3)

    let text0 = findNodes(in: headers[0], ofType: TextNode.self).map { $0.content }.joined()
    let text1 = findNodes(in: headers[1], ofType: TextNode.self).map { $0.content }.joined()
    #expect(text0 == "foo")
    #expect(text1 == "bar")

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 2)
    #expect(headers[0].level == 1)
    #expect(headers[1].level == 5)

    let text0 = findNodes(in: headers[0], ofType: TextNode.self).map { $0.content }.joined()
    let text1 = findNodes(in: headers[1], ofType: TextNode.self).map { $0.content }.joined()
    #expect(text0 == "foo")
    #expect(text1 == "foo")

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"foo\")],heading(level:5)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Spaces allowed after closing sequence")
  func spacesAllowedAfterClosingSequence() {
    let input = "### foo ###     "
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 3)

    let text = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "foo")

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hash characters with non-spaces become part of content")
  func hashCharactersWithNonSpacesBecomeContent() {
    let input = "### foo ### b"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 3)

    let text = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "foo ### b")

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo ### b\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing sequence must be preceded by space")
  func closingSequenceMustBePrecededBySpace() {
    let input = "# foo#"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 1)

    let text = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "foo#")

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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 3)
    #expect(headers[0].level == 3)
    #expect(headers[1].level == 2)
    #expect(headers[2].level == 1)

    let text0 = findNodes(in: headers[0], ofType: TextNode.self).map { $0.content }.joined()
    let text1 = findNodes(in: headers[1], ofType: TextNode.self).map { $0.content }.joined()
    let text2 = findNodes(in: headers[2], ofType: TextNode.self).map { $0.content }.joined()
    #expect(text0 == "foo ###")
    #expect(text1 == "foo ###")
    #expect(text2 == "foo #")

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:3)[text(\"foo ###\")],heading(level:2)[text(\"foo ###\")],heading(level:1)[text(\"foo #\")]]"
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
    #expect(result.errors.isEmpty)

    let thematicBreaks = findNodes(in: result.root, ofType: ThematicBreakNode.self)
    #expect(thematicBreaks.count == 2)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 2)

    let text = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "foo")

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
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers.first?.level == 1)

    let headerText = findNodes(in: headers.first!, ofType: TextNode.self).map { $0.content }.joined()
    #expect(headerText == "baz")

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo bar\")],heading(level:1)[text(\"baz\")],paragraph[text(\"Bar foo\")]]"
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
    #expect(result.errors.isEmpty)

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 3)
    #expect(headers[0].level == 2)
    #expect(headers[1].level == 1)
    #expect(headers[2].level == 3)

    // All headings should be empty (no text nodes)
    for header in headers {
      let textNodes = findNodes(in: header, ofType: TextNode.self)
      let allText = textNodes.map { $0.content }.joined()
      #expect(allText.isEmpty)
    }

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:2),heading(level:1),heading(level:3)]"
    #expect(sig(result.root) == expectedSig)
  }
}

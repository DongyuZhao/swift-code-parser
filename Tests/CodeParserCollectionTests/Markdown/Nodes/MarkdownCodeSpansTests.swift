import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Code Spans Tests - Spec 030")
struct MarkdownCodeSpansTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple code span with single backticks")
  func simpleCodeSpanWithSingleBackticks() {
    let input = "`foo`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo")

    let expectedSig = "document[paragraph[code(\"foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span with double backticks containing single backtick")
  func codeSpanWithDoubleBackticksContainingSingleBacktick() {
    let input = "`` foo ` bar ``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo ` bar")

    let expectedSig = "document[paragraph[code(\"foo ` bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span with leading and trailing spaces stripped to show double backticks")
  func codeSpanWithLeadingAndTrailingSpacesStrippedToShowDoubleBackticks() {
    let input = "` `` `"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "``")

    let expectedSig = "document[paragraph[code(\"``\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span strips only one space from each side")
  func codeSpanStripsOnlyOneSpaceFromEachSide() {
    let input = "`  ``  `"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == " `` ")

    let expectedSig = "document[paragraph[code(\" `` \")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span preserves leading space when no trailing space")
  func codeSpanPreservesLeadingSpaceWhenNoTrailingSpace() {
    let input = "` a`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == " a")

    let expectedSig = "document[paragraph[code(\" a\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span preserves unicode whitespace other than spaces")
  func codeSpanPreservesUnicodeWhitespaceOtherThanSpaces() {
    let input = "` b `"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == " b ")

    let expectedSig = "document[paragraph[code(\" b \")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code spans containing only spaces are not stripped")
  func codeSpansContainingOnlySpacesAreNotStripped() {
    let input = """
    ` `
    `  `
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 2)
    #expect(codeSpans[0].code == " ")
    #expect(codeSpans[1].code == "  ")

    let expectedSig = "document[paragraph[code(\" \"),text(\"\"),code(\"  \")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Line endings in code spans are converted to spaces")
  func lineEndingsInCodeSpansAreConvertedToSpaces() {
    let input = """
    ``
    foo
    bar
    baz
    ``
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo bar   baz")

    let expectedSig = "document[paragraph[code(\"foo bar   baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single line ending converted to space in code span")
  func singleLineEndingConvertedToSpaceInCodeSpan() {
    let input = """
    ``
    foo
    ``
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo ")

    let expectedSig = "document[paragraph[code(\"foo \")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Interior spaces are preserved in code spans")
  func interiorSpacesArePreservedInCodeSpans() {
    let input = """
    `foo   bar
    baz`
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo   bar  baz")

    let expectedSig = "document[paragraph[code(\"foo   bar  baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in code spans")
  func backslashEscapesDoNotWorkInCodeSpans() {
    let input = "`foo\\`bar`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo\\")

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "bar`")

    let expectedSig = "document[paragraph[code(\"foo\\\\\"),text(\"bar`\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple backticks can contain single backtick")
  func multipleBackticksCanContainSingleBacktick() {
    let input = "``foo`bar``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo`bar")

    let expectedSig = "document[paragraph[code(\"foo`bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span can contain double backticks")
  func codeSpanCanContainDoubleBackticks() {
    let input = "` foo `` bar `"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "foo `` bar")

    let expectedSig = "document[paragraph[code(\"foo `` bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code spans have higher precedence than emphasis")
  func codeSpansHaveHigherPrecedenceThanEmphasis() {
    let input = "*foo`*`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "*")

    let emphasisNodes = findNodes(in: paragraphs[0], ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "*foo")

    let expectedSig = "document[paragraph[text(\"*foo\"),code(\"*\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code spans have higher precedence than links")
  func codeSpansHaveHigherPrecedenceThanLinks() {
    let input = "[not a `link](/foo`)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "link](/foo")

    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "[not a ")
    #expect(textNodes[1].content == ")")

    let expectedSig = "document[paragraph[text(\"[not a \"),code(\"link](/foo\"),text(\")\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code spans and HTML tags have same precedence - code wins when it starts first")
  func codeSpansAndHTMLTagsHaveSamePrecedenceCodeWinsWhenItStartsFirst() {
    let input = "`<a href=\"`\">`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "<a href=\"")

    let htmlNodes = findNodes(in: paragraphs[0], ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "\">`")

    let expectedSig = "document[paragraph[code(\"<a href=\\\"\"),text(\"\\\">>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML tags win when they start before code spans")
  func htmlTagsWinWhenTheyStartBeforeCodeSpans() {
    let input = "<a href=\"`\">`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: paragraphs[0], ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)
    #expect(htmlNodes[0].content == "<a href=\"`\">")

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "`")

    let expectedSig = "document[paragraph[html(\"<a href=\\\"`\\\">\"),text(\"`\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code spans and autolinks have same precedence - code wins when it starts first")
  func codeSpansAndAutolinksHaveSamePrecedenceCodeWinsWhenItStartsFirst() {
    let input = "`<http://foo.bar.`baz>`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "<http://foo.bar.")

    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "baz>`")

    let expectedSig = "document[paragraph[code(\"<http://foo.bar.\"),text(\"baz>`\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Autolinks win when they start before code spans")
  func autolinksWinWhenTheyStartBeforeCodeSpans() {
    let input = "<http://foo.bar.`baz>`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 1)
    #expect(linkNodes[0].url == "http://foo.bar.`baz")

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 2)
    #expect(textNodes[0].content == "http://foo.bar.`baz")
    #expect(textNodes[1].content == "`")

    let expectedSig = "document[paragraph[link(url:\"http://foo.bar.`baz\",title:\"\")[text(\"http://foo.bar.`baz\")],text(\"`\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unmatched backtick strings remain as literal text")
  func unmatchedBacktickStringsRemainAsLiteralText() {
    let input = "```foo``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "```foo``")

    let expectedSig = "document[paragraph[text(\"```foo``\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single unclosed backtick remains as literal text")
  func singleUnclosedBacktickRemainsAsLiteralText() {
    let input = "`foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "`foo")

    let expectedSig = "document[paragraph[text(\"`foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backtick strings must be equal length to form code span")
  func backtickStringsMustBeEqualLengthToFormCodeSpan() {
    let input = "`foo``bar``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "bar")

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "`foo")

    let expectedSig = "document[paragraph[text(\"`foo\"),code(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty code span")
  func emptyCodeSpan() {
    let input = "``"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "")

    let expectedSig = "document[paragraph[code(\"\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span with only backticks inside")
  func codeSpanWithOnlyBackticksInside() {
    let input = "```````"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "`")

    let expectedSig = "document[paragraph[code(\"`\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple code spans in same paragraph")
  func multipleCodeSpansInSameParagraph() {
    let input = "Here is `code` and `more code`."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 2)
    #expect(codeSpans[0].code == "code")
    #expect(codeSpans[1].code == "more code")

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 3)
    #expect(textNodes[0].content == "Here is ")
    #expect(textNodes[1].content == " and ")
    #expect(textNodes[2].content == ".")

    let expectedSig = "document[paragraph[text(\"Here is \"),code(\"code\"),text(\" and \"),code(\"more code\"),text(\".\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Code span with special characters")
  func codeSpanWithSpecialCharacters() {
    let input = "`<>&\"`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "<>&\"")

    let expectedSig = "document[paragraph[code(\"<>&\\\"\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

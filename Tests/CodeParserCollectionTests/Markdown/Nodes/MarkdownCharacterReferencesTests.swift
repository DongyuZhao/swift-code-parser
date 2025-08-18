import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Entity and Numeric Character References Tests - Spec 029")
struct MarkdownEntityAndNumericCharacterReferencesTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Valid HTML entity references are converted to Unicode characters")
  func validHTMLEntityReferencesAreConvertedToUnicodeCharacters() {
    let input = """
    &nbsp; &amp; &copy; &AElig; &Dcaron;
    &frac34; &HilbertSpace; &DifferentialD;
    &ClockwiseContourIntegral; &ngE;
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count >= 1)

    // Verify that entities are converted to their Unicode equivalents
    let fullText = innerText(paragraphs[0])
    #expect(fullText.contains(" ") && fullText.contains("&") && fullText.contains("©") && fullText.contains("Æ") && fullText.contains("Ď"))

    let expectedSig = "document[paragraph[text(\"  & © Æ Ď\"),text(\"¾ ℋ ⅆ\"),text(\"∲ ≧̸\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Decimal numeric character references are parsed as Unicode characters")
  func decimalNumericCharacterReferencesAreParsedAsUnicodeCharacters() {
    let input = "&#35; &#1234; &#992; &#0;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // &#35; = #, &#1234; = Ӓ, &#992; = Ϡ, &#0; = replacement character
    let text = textNodes[0].content
    #expect(text.contains("#"))

    let expectedSig = "document[paragraph[text(\"# Ӓ Ϡ �\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hexadecimal numeric character references are parsed as Unicode characters")
  func hexadecimalNumericCharacterReferencesAreParsedAsUnicodeCharacters() {
    let input = "&#X22; &#XD06; &#xcab;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // &#X22; = ", &#XD06; = ആ, &#xcab; = ಫ
    let text = textNodes[0].content
    #expect(text.contains("\""))

    let expectedSig = "document[paragraph[text(\"\\\" ആ ಫ\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid entity and character references remain as literal text")
  func invalidEntityAndCharacterReferencesRemainAsLiteralText() {
    let input = """
    &nbsp &x; &#; &#x;
    &#987654321;
    &#abcdef0;
    &ThisIsNotDefined; &hi?;
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count >= 1)

    // All invalid references should remain as literal ampersands
    let fullText = innerText(paragraphs[0])
    #expect(fullText.contains("&nbsp"))
    #expect(fullText.contains("&x;"))
    #expect(fullText.contains("&#;"))
    #expect(fullText.contains("&ThisIsNotDefined;"))

    let expectedSig = "document[paragraph[text(\"&nbsp &x; &#; &#x;\"),text(\"&#987654321;\"),text(\"&#abcdef0;\"),text(\"&ThisIsNotDefined; &hi?;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references without trailing semicolon are not recognized")
  func entityReferencesWithoutTrailingSemicolonAreNotRecognized() {
    let input = "&copy"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "&copy")

    let expectedSig = "document[paragraph[text(\"&copy\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unknown entity names are not recognized as entity references")
  func unknownEntityNamesAreNotRecognizedAsEntityReferences() {
    let input = "&MadeUpEntity;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "&MadeUpEntity;")

    let expectedSig = "document[paragraph[text(\"&MadeUpEntity;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in raw HTML")
  func entityReferencesWorkInRawHTML() {
    let input = "<a href=\"&ouml;&ouml;.html\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)
    #expect(htmlNodes[0].content == "<a href=\"&ouml;&ouml;.html\">")

    let expectedSig = "document[html(\"<a href=\\\"&ouml;&ouml;.html\\\">\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in link URLs and titles")
  func entityReferencesWorkInLinkURLsAndTitles() {
    let input = "[foo](/f&ouml;&ouml; \"f&ouml;&ouml;\")"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 1)
    #expect(linkNodes[0].url == "/föö")
    #expect(linkNodes[0].title == "föö")
    #expect(innerText(linkNodes[0]) == "foo")

    let expectedSig = "document[paragraph[link(url:\"/föö\",title:\"föö\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in link reference definitions")
  func entityReferencesWorkInLinkReferenceDefinitions() {
    let input = """
    [foo]

    [foo]: /f&ouml;&ouml; "f&ouml;&ouml;"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 1)
    #expect(linkNodes[0].url == "/föö")
    #expect(linkNodes[0].title == "föö")

    let referenceNodes = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(referenceNodes.count == 1)
    #expect(referenceNodes[0].url == "/föö")
    #expect(referenceNodes[0].title == "föö")

    let expectedSig = "document[paragraph[link(url:\"/föö\",title:\"föö\")[text(\"foo\")]],reference(id:\"foo\",url:\"/föö\",title:\"föö\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in fenced code block info strings")
  func entityReferencesWorkInFencedCodeBlockInfoStrings() {
    let input = """
    ``` f&ouml;&ouml;
    foo
    ```
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].language == "föö")
    #expect(codeBlocks[0].source == "foo")

    let expectedSig = "document[code_block(lang:\"föö\",\"foo\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references treated as literal text in code spans")
  func entityReferencesTreatedAsLiteralTextInCodeSpans() {
    let input = "`f&ouml;&ouml;`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let codeSpans = findNodes(in: paragraphs[0], ofType: CodeSpanNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans[0].code == "f&ouml;&ouml;")

    let expectedSig = "document[paragraph[code(\"f&ouml;&ouml;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references treated as literal text in indented code blocks")
  func entityReferencesTreatedAsLiteralTextInIndentedCodeBlocks() {
    let input = "    f&ouml;f&ouml;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "f&ouml;f&ouml;")

    let expectedSig = "document[code_block(\"f&ouml;f&ouml;\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character references cannot replace structural markdown symbols")
  func numericCharacterReferencesCannotReplaceStructuralMarkdownSymbols() {
    let input = """
    &#42;foo&#42;
    *foo*
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // First line should be literal asterisks, second should be emphasis
    let emphasisNodes = findNodes(in: paragraphs[0], ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)
    #expect(innerText(emphasisNodes[0]) == "foo")

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count >= 1)

    let expectedSig = "document[paragraph[text(\"*foo*\"),text(\"\"),emphasis[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character references cannot create list markers")
  func numericCharacterReferencesCannotCreateListMarkers() {
    let input = """
    &#42; foo

    * foo
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "* foo")

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)
    #expect(innerText(listItems[0]) == "foo")

    let expectedSig = "document[paragraph[text(\"* foo\")],unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character references for line breaks preserve paragraph structure")
  func numericCharacterReferencesForLineBreaksPreserveParagraphStructure() {
    let input = "foo&#10;&#10;bar"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // The line breaks should be converted to actual newlines but remain in same paragraph
    let text = textNodes[0].content
    #expect(text.contains("foo") && text.contains("bar"))

    let expectedSig = "document[paragraph[text(\"foo\\n\\nbar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character reference for tab character")
  func numericCharacterReferenceForTabCharacter() {
    let input = "&#9;foo"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "\tfoo")

    let expectedSig = "document[paragraph[text(\"\\tfoo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid link syntax with entity references remains literal")
  func invalidLinkSyntaxWithEntityReferencesRemainsLiteral() {
    let input = "[a](url &quot;tit&quot;)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    // Should not create a link due to invalid syntax
    let linkNodes = findNodes(in: paragraphs[0], ofType: LinkNode.self)
    #expect(linkNodes.count == 0)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "[a](url \"tit\")")

    let expectedSig = "document[paragraph[text(\"[a](url \\\"tit\\\")\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Common HTML entities are properly converted")
  func commonHTMLEntitiesAreProperlyConverted() {
    let input = "&lt; &gt; &amp; &quot; &#39;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    #expect(textNodes[0].content == "< > & \" '")

    let expectedSig = "document[paragraph[text(\"< > & \\\" '\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references in emphasis do not break formatting")
  func entityReferencesInEmphasisDoNotBreakFormatting() {
    let input = "*foo &amp; bar*"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let emphasisNodes = findNodes(in: paragraphs[0], ofType: EmphasisNode.self)
    #expect(emphasisNodes.count == 1)
    #expect(innerText(emphasisNodes[0]) == "foo & bar")

    let expectedSig = "document[paragraph[emphasis[text(\"foo & bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed entity and numeric character references")
  func mixedEntityAndNumericCharacterReferences() {
    let input = "&copy; &#169; &#xA9;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    // All three should produce the copyright symbol
    #expect(textNodes[0].content == "© © ©")

    let expectedSig = "document[paragraph[text(\"© © ©\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references with invalid hexadecimal syntax")
  func entityReferencesWithInvalidHexadecimalSyntax() {
    let input = "&#xgg; &#XZZ;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let textNodes = findNodes(in: paragraphs[0], ofType: TextNode.self)
    #expect(textNodes.count == 1)
    // Invalid hex should remain as literal text
    #expect(textNodes[0].content == "&#xgg; &#XZZ;")

    let expectedSig = "document[paragraph[text(\"&#xgg; &#XZZ;\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

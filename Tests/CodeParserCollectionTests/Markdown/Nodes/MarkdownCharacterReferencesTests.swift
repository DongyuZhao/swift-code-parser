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

    let expectedSig = "document[paragraph[text(\"  & © Æ Ď\"),text(\"¾ ℋ ⅆ\"),text(\"∲ ≧̸\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Decimal numeric character references are parsed as Unicode characters")
  func decimalNumericCharacterReferencesAreParsedAsUnicodeCharacters() {
    let input = "&#35; &#1234; &#992; &#0;"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"# Ӓ Ϡ �\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Hexadecimal numeric character references are parsed as Unicode characters")
  func hexadecimalNumericCharacterReferencesAreParsedAsUnicodeCharacters() {
    let input = "&#X22; &#XD06; &#xcab;"
    let result = parser.parse(input, language: language)

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

    let expectedSig = "document[paragraph[text(\"&nbsp &x; &#; &#x;\"),text(\"&#987654321;\"),text(\"&#abcdef0;\"),text(\"&ThisIsNotDefined; &hi?;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references without trailing semicolon are not recognized")
  func entityReferencesWithoutTrailingSemicolonAreNotRecognized() {
    let input = "&copy"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"&copy\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unknown entity names are not recognized as entity references")
  func unknownEntityNamesAreNotRecognizedAsEntityReferences() {
    let input = "&MadeUpEntity;"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"&MadeUpEntity;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in raw HTML")
  func entityReferencesWorkInRawHTML() {
    let input = "<a href=\"&ouml;&ouml;.html\">"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[html(\"<a href=\\\"&ouml;&ouml;.html\\\">\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references work in link URLs and titles")
  func entityReferencesWorkInLinkURLsAndTitles() {
    let input = "[foo](/f&ouml;&ouml; \"f&ouml;&ouml;\")"
    let result = parser.parse(input, language: language)

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

    let expectedSig = "document[code_block(lang:\"föö\",\"foo\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references treated as literal text in code spans")
  func entityReferencesTreatedAsLiteralTextInCodeSpans() {
    let input = "`f&ouml;&ouml;`"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[code(\"f&ouml;&ouml;\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references treated as literal text in indented code blocks")
  func entityReferencesTreatedAsLiteralTextInIndentedCodeBlocks() {
    let input = "    f&ouml;f&ouml;"
    let result = parser.parse(input, language: language)

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

    let expectedSig = "document[paragraph[text(\"* foo\")],unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character references for line breaks preserve paragraph structure")
  func numericCharacterReferencesForLineBreaksPreserveParagraphStructure() {
    let input = "foo&#10;&#10;bar"
    let result = parser.parse(input, language: language)

  let expectedSig = "document[paragraph[text(\"foo\"),line_break(soft),line_break(soft),text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Numeric character reference for tab character")
  func numericCharacterReferenceForTabCharacter() {
    let input = "&#9;foo"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"\\tfoo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid link syntax with entity references remains literal")
  func invalidLinkSyntaxWithEntityReferencesRemainsLiteral() {
    let input = "[a](url &quot;tit&quot;)"
    let result = parser.parse(input, language: language)

    // Should not create a link due to invalid syntax

    let expectedSig = "document[paragraph[text(\"[a](url \\\"tit\\\")\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Common HTML entities are properly converted")
  func commonHTMLEntitiesAreProperlyConverted() {
    let input = "&lt; &gt; &amp; &quot; &#39;"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[text(\"< > & \\\" '\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references in emphasis do not break formatting")
  func entityReferencesInEmphasisDoNotBreakFormatting() {
    let input = "*foo &amp; bar*"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[paragraph[emphasis[text(\"foo & bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed entity and numeric character references")
  func mixedEntityAndNumericCharacterReferences() {
    let input = "&copy; &#169; &#xA9;"
    let result = parser.parse(input, language: language)

    // All three should produce the copyright symbol

    let expectedSig = "document[paragraph[text(\"© © ©\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity references with invalid hexadecimal syntax")
  func entityReferencesWithInvalidHexadecimalSyntax() {
    let input = "&#xgg; &#XZZ;"
    let result = parser.parse(input, language: language)

    // Invalid hex should remain as literal text

    let expectedSig = "document[paragraph[text(\"&#xgg; &#XZZ;\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

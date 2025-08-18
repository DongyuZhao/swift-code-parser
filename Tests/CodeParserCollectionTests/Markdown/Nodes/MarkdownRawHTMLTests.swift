import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Raw HTML Tests - Spec 037")
struct MarkdownRawHTMLTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Simple open tags parsed as HTML within paragraph")
  func simpleOpenTags() {
    let input = "<a><bab><c2c>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 3)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"<a>\"),html(\"<bab>\"),html(\"<c2c>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty elements with self-closing syntax")
  func emptyElements() {
    let input = "<a/><b2/>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"<a/>\"),html(\"<b2/>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML tags with whitespace allowed")
  func htmlTagsWithWhitespace() {
    let input = """
<a  /><b2
data="foo" >
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"<a  />\"),html(\"<b2\\ndata=\\\"foo\\\" >\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML tags with various attribute types")
  func htmlTagsWithAttributes() {
    let input = """
<a foo="bar" bam = 'baz <em>"</em>'
_boolean zoop:33=zoop:33 />
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"<a foo=\\\"bar\\\" bam = 'baz <em>\\\"</em>'\\n_boolean zoop:33=zoop:33 />\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Custom tag names are allowed")
  func customTagNames() {
    let input = "Foo <responsive-image src=\"foo.jpg\" />"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"Foo \"),html(\"<responsive-image src=\\\"foo.jpg\\\" />\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Illegal tag names not parsed as HTML")
  func illegalTagNames() {
    let input = "<33> <__>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - illegal tags become text
    let expectedSig = "document[paragraph[text(\"<33> <__>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Illegal attribute names not parsed as HTML")
  func illegalAttributeNames() {
    let input = "<a h*#ref=\"hi\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - illegal attributes make tag become text
    let expectedSig = "document[paragraph[text(\"<a h*#ref=\\\"hi\\\">\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Illegal attribute values not parsed as HTML")
  func illegalAttributeValues() {
    let input = "<a href=\"hi'> <a href=hi'>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - malformed quotes make tags become text
    let expectedSig = "document[paragraph[text(\"<a href=\\\"hi'> <a href=hi'>\"  )]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Illegal whitespace in tags not parsed as HTML")
  func illegalWhitespace() {
    let input = """
< a><
foo><bar/ >
<foo bar=baz
bim!bop />
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - illegal whitespace makes tags become text
    let expectedSig = "document[paragraph[text(\"< a><\\nfoo><bar/ >\\n<foo bar=baz\\nbim!bop />\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Missing whitespace between attributes not parsed as HTML")
  func missingWhitespace() {
    let input = "<a href='bar'title=title>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - missing whitespace makes tag become text
    let expectedSig = "document[paragraph[text(\"<a href='bar'title=title>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Closing tags parsed as HTML")
  func closingTags() {
    let input = "</a></foo >"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"</a>\"),html(\"</foo >\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Illegal attributes in closing tag not parsed as HTML")
  func illegalAttributesInClosingTag() {
    let input = "</a href=\"foo\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - closing tags cannot have attributes
    let expectedSig = "document[paragraph[text(\"</a href=\\\"foo\\\">\"  )]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML comments parsed as HTML")
  func htmlComments() {
    let input = """
foo <!-- this is a --
comment - with hyphens -->
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<!-- this is a --\\ncomment - with hyphens -->\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Special HTML comment forms")
  func specialHTMLCommentForms() {
    let input = """
foo <!--> foo -->

foo <!---> foo -->
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 2)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<!-->\"),text(\" foo -->\")],paragraph[text(\"foo \"),html(\"<!--->\"),text(\" foo -->\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Processing instructions parsed as HTML")
  func processingInstructions() {
    let input = "foo <?php echo $a; ?>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<?php echo $a; ?>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Declarations parsed as HTML")
  func declarations() {
    let input = "foo <!ELEMENT br EMPTY>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<!ELEMENT br EMPTY>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("CDATA sections parsed as HTML")
  func cdataSections() {
    let input = "foo <![CDATA[>&<]]>"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<![CDATA[>&<]]>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Entity and numeric character references preserved in HTML attributes")
  func entityReferencesInAttributes() {
    let input = "foo <a href=\"&ouml;\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<a href=\\\"&ouml;\\\">\"  )]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in HTML attributes")
  func backslashEscapesInAttributes() {
    let input = "foo <a href=\"\\*\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 1)

    // Verify AST structure using sig - backslashes are preserved literally
    let expectedSig = "document[paragraph[text(\"foo \"),html(\"<a href=\\\"\\\\*\\\">\"  )]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unescaped quotes in HTML attributes not parsed as HTML")
  func unescapedQuotesInAttributes() {
    let input = "<a href=\"\\\"\">"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let htmlNodes = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(htmlNodes.count == 0)

    let textNodes = findNodes(in: result.root, ofType: TextNode.self)
    #expect(textNodes.count == 1)

    // Verify AST structure using sig - malformed quotes make tag become text
    let expectedSig = "document[paragraph[text(\"<a href=\\\"\\\\\\\"\\\">\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

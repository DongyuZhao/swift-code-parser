import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Link Reference Definitions Tests - Spec 020")
struct MarkdownLinkReferenceDefinitionsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Basic link reference definition with title")
  func basicLinkReferenceDefinitionWithTitle() {
    let input = """
    [foo]: /url "title"

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "title")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url")
    #expect(link.title == "title")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"title\"),paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition with indentation and multiline title")
  func linkReferenceDefinitionWithIndentationAndMultilineTitle() {
    let input = """
       [foo]:
          /url
               'the title'

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "the title")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url")
    #expect(link.title == "the title")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"the title\"),paragraph[link(url:\"/url\",title:\"the title\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition with special characters in label")
  func linkReferenceDefinitionWithSpecialCharactersInLabel() {
    let input = """
    [Foo*bar\\]]:my_(url) 'title (with parens)'

    [Foo*bar\\]]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "Foo*bar\\]")
    #expect(reference.url == "my_(url)")
    #expect(reference.title == "title (with parens)")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "my_(url)")
    #expect(link.title == "title (with parens)")
    #expect(innerText(link) == "Foo*bar]")

    let expectedSig = "document[reference(id:\"Foo*bar\\\\]\",url:\"my_(url)\",title:\"title (with parens)\"),paragraph[link(url:\"my_(url)\",title:\"title (with parens)\")[text(\"Foo*bar]\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition with angle brackets in URL")
  func linkReferenceDefinitionWithAngleBracketsInURL() {
    let input = """
    [Foo bar]:
    <my url>
    'title'

    [Foo bar]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "Foo bar")
    #expect(reference.url == "my url")
    #expect(reference.title == "title")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "my%20url")
    #expect(link.title == "title")
    #expect(innerText(link) == "Foo bar")

    let expectedSig = "document[reference(id:\"Foo bar\",url:\"my url\",title:\"title\"),paragraph[link(url:\"my%20url\",title:\"title\")[text(\"Foo bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Title extending over multiple lines")
  func titleExtendingOverMultipleLines() {
    let input = """
    [foo]: /url '
    title
    line1
    line2
    '

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "\ntitle\nline1\nline2\n")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url")
    #expect(link.title == "\ntitle\nline1\nline2\n")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\\ntitle\\nline1\\nline2\\n\"),paragraph[link(url:\"/url\",title:\"\\ntitle\\nline1\\nline2\\n\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Title with blank line creates invalid reference definition")
  func titleWithBlankLineCreatesInvalidReferenceDefinition() {
    let input = """
    [foo]: /url 'title

    with blank line'

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to blank line in title
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create paragraphs instead
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 3)

    let expectedSig = "document[paragraph[text(\"[foo]: /url 'title\")],paragraph[text(\"with blank line'\")],paragraph[text(\"[foo]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition without title")
  func linkReferenceDefinitionWithoutTitle() {
    let input = """
    [foo]:
    /url

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url")
    #expect(link.title == "")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition missing destination")
  func linkReferenceDefinitionMissingDestination() {
    let input = """
    [foo]:

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to missing destination
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create paragraphs instead
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let expectedSig = "document[paragraph[text(\"[foo]:\")],paragraph[text(\"[foo]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Empty link destination using angle brackets")
  func emptyLinkDestinationUsingAngleBrackets() {
    let input = """
    [foo]: <>

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "")
    #expect(link.title == "")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"\",title:\"\"),paragraph[link(url:\"\",title:\"\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Title must be separated from destination by whitespace")
  func titleMustBeSeparatedFromDestinationByWhitespace() {
    let input = """
    [foo]: <bar>(baz)

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to improper title separation
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create paragraphs instead
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)

    let expectedSig = "document[paragraph[text(\"[foo]: <bar>(baz)\")],paragraph[text(\"[foo]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes in title and destination")
  func backslashEscapesInTitleAndDestination() {
    let input = """
    [foo]: /url\\bar\\*baz "foo\\"bar\\baz"

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url\\bar\\*baz")
    #expect(reference.title == "foo\"bar\\baz")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url%5Cbar*baz")
    #expect(link.title == "foo&quot;bar\\baz")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\\\\bar\\\\*baz\",title:\"foo\\\"bar\\\\baz\"),paragraph[link(url:\"/url%5Cbar*baz\",title:\"foo&quot;bar\\\\baz\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link comes before its corresponding definition")
  func linkComesBeforeItsCorrespondingDefinition() {
    let input = """
    [foo]

    [foo]: url
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "url")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "url")
    #expect(link.title == "")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[paragraph[link(url:\"url\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"url\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("First matching definition takes precedence")
  func firstMatchingDefinitionTakesPrecedence() {
    let input = """
    [foo]

    [foo]: first
    [foo]: second
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 2)

    // Should use the first definition
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "first")
    #expect(link.title == "")
    #expect(innerText(link) == "foo")

    let expectedSig = "document[paragraph[link(url:\"first\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"first\",title:\"\"),reference(id:\"foo\",url:\"second\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Case insensitive label matching")
  func caseInsensitiveLabelMatching() {
    let input = """
    [FOO]: /url

    [Foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "FOO")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/url")
    #expect(link.title == "")
    #expect(innerText(link) == "Foo")

    let expectedSig = "document[reference(id:\"FOO\",url:\"/url\",title:\"\"),paragraph[link(url:\"/url\",title:\"\")[text(\"Foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Unicode case insensitive matching")
  func unicodeCaseInsensitiveMatching() {
    let input = """
    [ΑΓΩ]: /φου

    [αγω]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "ΑΓΩ")
    #expect(reference.url == "/φου")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)

    let link = links[0]
    #expect(link.url == "/%CF%86%CE%BF%CF%85")
    #expect(link.title == "")
    #expect(innerText(link) == "αγω")

    let expectedSig = "document[reference(id:\"ΑΓΩ\",url:\"/φου\",title:\"\"),paragraph[link(url:\"/%CF%86%CE%BF%CF%85\",title:\"\")[text(\"αγω\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition with no corresponding link")
  func linkReferenceDefinitionWithNoCorrespondingLink() {
    let input = "[foo]: /url"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    // No links should be created
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 0)

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiline link reference definition label")
  func multilineLinkReferenceDefinitionLabel() {
    let input = """
    [
    foo
    ]: /url
    bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "bar")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid link reference definition with extra content after title")
  func invalidLinkReferenceDefinitionWithExtraContentAfterTitle() {
    let input = "[foo]: /url \"title\" ok"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to extra content
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create a paragraph instead
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)

    let expectedSig = "document[paragraph[text(\"[foo]: /url \\\"title\\\" ok\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Valid link reference definition followed by quoted title on next line")
  func validLinkReferenceDefinitionFollowedByQuotedTitleOnNextLine() {
    let input = """
    [foo]: /url
    "title" ok
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "\"title\" ok")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),paragraph[text(\"\\\"title\\\" ok\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition indented four spaces becomes code block")
  func linkReferenceDefinitionIndentedFourSpacesBecomesCodeBlock() {
    let input = """
        [foo]: /url "title"

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to indentation
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create a code block and paragraph
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "[foo]: /url \"title\"")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "[foo]")

    let expectedSig = "document[code_block(\"[foo]: /url \\\"title\\\"\"),paragraph[text(\"[foo]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition inside code block")
  func linkReferenceDefinitionInsideCodeBlock() {
    let input = """
    ```
    [foo]: /url
    ```

    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to being in code block
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create a code block and paragraph
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks[0].source == "[foo]: /url")

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "[foo]")

    let expectedSig = "document[code_block(\"[foo]: /url\"),paragraph[text(\"[foo]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition cannot interrupt paragraph")
  func linkReferenceDefinitionCannotInterruptParagraph() {
    let input = """
    Foo
    [bar]: /baz

    [bar]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should not create a reference definition due to interrupting paragraph
    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 0)

    // Should create paragraphs
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "Foo\n[bar]: /baz")
    #expect(innerText(paragraphs[1]) == "[bar]")

    let expectedSig = "document[paragraph[text(\"Foo\"),text(\"[bar]: /baz\")],paragraph[text(\"[bar]\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition after heading and before blockquote")
  func linkReferenceDefinitionAfterHeadingAndBeforeBlockquote() {
    let input = """
    # [Foo]
    [foo]: /url
    > bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)

    let links = findNodes(in: headers[0], ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links[0].url == "/url")
    #expect(innerText(links[0]) == "Foo")

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[heading(level:1)[link(url:\"/url\",title:\"\")[text(\"Foo\")]],reference(id:\"foo\",url:\"/url\",title:\"\"),blockquote[paragraph[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition followed by setext heading")
  func linkReferenceDefinitionFollowedBySetextHeading() {
    let input = """
    [foo]: /url
    bar
    ===
    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 1)
    #expect(headers[0].level == 1)
    #expect(innerText(headers[0]) == "bar")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links[0].url == "/url")
    #expect(innerText(links[0]) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),heading(level:1)[text(\"bar\")],paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid setext heading after link reference definition")
  func invalidSetextHeadingAfterLinkReferenceDefinition() {
    let input = """
    [foo]: /url
    ===
    [foo]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    // === cannot form setext heading without content
    let headers = findNodes(in: result.root, ofType: HeaderNode.self)
    #expect(headers.count == 0)

    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 2)
    #expect(innerText(paragraphs[0]) == "===")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links[0].url == "/url")
    #expect(innerText(links[0]) == "foo")

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),paragraph[text(\"===\")],paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple consecutive link reference definitions")
  func multipleConsecutiveLinkReferenceDefinitions() {
    let input = """
    [foo]: /foo-url "foo"
    [bar]: /bar-url
      "bar"
    [baz]: /baz-url

    [foo],
    [bar],
    [baz]
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 3)

    #expect(references[0].identifier == "foo")
    #expect(references[0].url == "/foo-url")
    #expect(references[0].title == "foo")

    #expect(references[1].identifier == "bar")
    #expect(references[1].url == "/bar-url")
    #expect(references[1].title == "bar")

    #expect(references[2].identifier == "baz")
    #expect(references[2].url == "/baz-url")
    #expect(references[2].title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 3)

    #expect(links[0].url == "/foo-url")
    #expect(links[0].title == "foo")
    #expect(innerText(links[0]) == "foo")

    #expect(links[1].url == "/bar-url")
    #expect(links[1].title == "bar")
    #expect(innerText(links[1]) == "bar")

    #expect(links[2].url == "/baz-url")
    #expect(links[2].title == "")
    #expect(innerText(links[2]) == "baz")

    let expectedSig = "document[reference(id:\"foo\",url:\"/foo-url\",title:\"foo\"),reference(id:\"bar\",url:\"/bar-url\",title:\"bar\"),reference(id:\"baz\",url:\"/baz-url\",title:\"\"),paragraph[link(url:\"/foo-url\",title:\"foo\")[text(\"foo\")],text(\",\"),link(url:\"/bar-url\",title:\"bar\")[text(\"bar\")],text(\",\"),link(url:\"/baz-url\",title:\"\")[text(\"baz\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition inside blockquote affects entire document")
  func linkReferenceDefinitionInsideBlockquoteAffectsEntireDocument() {
    let input = """
    [foo]

    > [foo]: /url
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links[0].url == "/url")
    #expect(innerText(links[0]) == "foo")

    let blockquotes = findNodes(in: result.root, ofType: BlockquoteNode.self)
    #expect(blockquotes.count == 1)

    let expectedSig = "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]],blockquote[reference(id:\"foo\",url:\"/url\",title:\"\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Standalone link reference definition with no visible content")
  func standaloneLinkReferenceDefinitionWithNoVisibleContent() {
    let input = "[foo]: /url"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let references = findNodes(in: result.root, ofType: ReferenceNode.self)
    #expect(references.count == 1)

    let reference = references[0]
    #expect(reference.identifier == "foo")
    #expect(reference.url == "/url")
    #expect(reference.title == "")

    // No other content should be generated
    let paragraphs = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paragraphs.count == 0)

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }
}

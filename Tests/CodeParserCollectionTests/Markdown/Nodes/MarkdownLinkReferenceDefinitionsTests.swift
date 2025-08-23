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

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\ntitle\nline1\nline2\n\"),paragraph[link(url:\"/url\",title:\"\ntitle\nline1\nline2\n\")[text(\"foo\")]]]"
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

    let expectedSig = "document[reference(id:\"ΑΓΩ\",url:\"/φου\",title:\"\"),paragraph[link(url:\"/%CF%86%CE%BF%CF%85\",title:\"\")[text(\"αγω\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Link reference definition with no corresponding link")
  func linkReferenceDefinitionWithNoCorrespondingLink() {
    let input = "[foo]: /url"
    let result = parser.parse(input, language: language)

    // No links should be created

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

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\"),paragraph[text(\"bar\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid link reference definition with extra content after title")
  func invalidLinkReferenceDefinitionWithExtraContentAfterTitle() {
    let input = "[foo]: /url \"title\" ok"
    let result = parser.parse(input, language: language)

    // Should not create a reference definition due to extra content

    // Should create a paragraph instead

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

    // Should not create a reference definition due to indentation

    // Should create a code block and paragraph

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

    // Should not create a reference definition due to being in code block

    // Should create a code block and paragraph

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

    // Should not create a reference definition due to interrupting paragraph

    // Should create paragraphs

  let expectedSig = "document[paragraph[text(\"Foo\"),line_break(soft),text(\"[bar]: /baz\")],paragraph[text(\"[bar]\")]]"
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

    let expectedSig = "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]],blockquote[reference(id:\"foo\",url:\"/url\",title:\"\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Standalone link reference definition with no visible content")
  func standaloneLinkReferenceDefinitionWithNoVisibleContent() {
    let input = "[foo]: /url"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[reference(id:\"foo\",url:\"/url\",title:\"\")]"
    #expect(sig(result.root) == expectedSig)
  }
}

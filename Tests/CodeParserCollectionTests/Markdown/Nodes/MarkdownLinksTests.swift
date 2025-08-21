import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Links Tests - Spec 033")
struct MarkdownLinksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Basic inline links

  @Test("Simple inline link with title")
  func simpleInlineLinkWithTitle() {
    let input = "[link](/uri \"title\")"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"title\")[text(\"link\")]]]")
  }

  @Test("Inline link without title")
  func inlineLinkWithoutTitle() {
    let input = "[link](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Empty inline link destination and title")
  func emptyInlineLinkDestinationAndTitle() {
    let input = "[link]()"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Empty inline link destination in pointy brackets")
  func emptyInlineLinkDestinationInPointyBrackets() {
    let input = "[link](<>)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"link\")]]]")
  }

  // MARK: - Link destination with spaces

  @Test("Link destination with spaces is not parsed as link")
  func linkDestinationWithSpacesNotParsedAsLink() {
    let input = "[link](/my uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link](/my uri)\")]]")
  }

  @Test("Link destination with spaces in pointy brackets")
  func linkDestinationWithSpacesInPointyBrackets() {
    let input = "[link](</my uri>)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/my%20uri\",title:\"\")[text(\"link\")]]]")
  }

  // MARK: - Link destination with line breaks

  @Test("Link destination with line breaks not parsed as link")
  func linkDestinationWithLineBreaksNotParsedAsLink() {
    let input = """
    [link](foo
    bar)
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link](foo\"),line_break(soft),text(\"bar)\")]]")
  }

  @Test("Link destination with line breaks in pointy brackets not parsed as link")
  func linkDestinationWithLineBreaksInPointyBracketsNotParsedAsLink() {
    let input = """
    [link](<foo
    bar>)
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link](<foo\"),line_break(soft),text(\"bar>)\")]]")
  }

  // MARK: - Link destination with parentheses

  @Test("Link destination with parentheses in pointy brackets")
  func linkDestinationWithParenthesesInPointyBrackets() {
    let input = "[a](<b)c>)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"b)c\",title:\"\")[text(\"a\")]]]")
  }

  @Test("Pointy brackets must be unescaped for link")
  func pointyBracketsMustBeUnescapedForLink() {
    let input = "[link](<foo\\>)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link](<foo>)\")]]")
  }

  @Test("Unmatched pointy brackets do not create links")
  func unmatchedPointyBracketsDoNotCreateLinks() {
    let input = """
    [a](<b)c
    [a](<b)c>
    [a](<b>c)
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[a](<b)c\"),line_break(soft),text(\"[a](<b)c>\"),line_break(soft),text(\"[a](<b>c)\")]]")
  }

  @Test("Escaped parentheses in link destination")
  func escapedParenthesesInLinkDestination() {
    let input = "[link](\\(foo\\))"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"(foo)\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Balanced parentheses in link destination")
  func balancedParenthesesInLinkDestination() {
    let input = "[link](foo(and(bar)))"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo(and(bar))\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Unbalanced escaped parentheses in link destination")
  func unbalancedEscapedParenthesesInLinkDestination() {
    let input = "[link](foo\\(and\\(bar\\))"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo(and(bar)\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Unbalanced parentheses in pointy brackets")
  func unbalancedParenthesesInPointyBrackets() {
    let input = "[link](<foo(and(bar)>)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo(and(bar)\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Escaped symbols in link destination")
  func escapedSymbolsInLinkDestination() {
    let input = "[link](foo\\)\\:)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo):\",title:\"\")[text(\"link\")]]]")
  }

  // MARK: - Link fragments and queries

  @Test("Link with fragment identifiers and queries")
  func linkWithFragmentIdentifiersAndQueries() {
    let input = """
    [link](#fragment)

    [link](http://example.com#fragment)

    [link](http://example.com?foo=3#frag)
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"#fragment\",title:\"\")[text(\"link\")]],paragraph[link(url:\"http://example.com#fragment\",title:\"\")[text(\"link\")]],paragraph[link(url:\"http://example.com?foo=3#frag\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Backslash before non-escapable character remains as backslash")
  func backslashBeforeNonEscapableCharacterRemainsAsBackslash() {
    let input = "[link](foo\\bar)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo%5Cbar\",title:\"\")[text(\"link\")]]]")
  }

  @Test("URL-escaped characters and entities in destination")
  func urlEscapedCharactersAndEntitiesInDestination() {
    let input = "[link](foo%20b&auml;)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"foo%20b%C3%A4\",title:\"\")[text(\"link\")]]]")
  }

  // MARK: - Link titles

  @Test("Title parsed as destination when destination omitted")
  func titleParsedAsDestinationWhenDestinationOmitted() {
    let input = "[link](\"title\")"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"%22title%22\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Titles in different quote types")
  func titlesInDifferentQuoteTypes() {
    let input = """
    [link](/url "title")
    [link](/url 'title')
    [link](/url (title))
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"link\")],line_break(soft),link(url:\"/url\",title:\"title\")[text(\"link\")],line_break(soft),link(url:\"/url\",title:\"title\")[text(\"link\")]]]")
  }

  @Test("Backslash escapes and entities in titles")
  func backslashEscapesAndEntitiesInTitles() {
    let input = "[link](/url \"title \\\"&quot;\")"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title \\\"&quot;\\\"\")[text(\"link\")]]]")
  }

  @Test("Non-breaking space in title URL-encodes")
  func nonBreakingSpaceInTitleUrlEncodes() {
    let input = "[link](/url \"title\")"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url%C2%A0%22title%22\",title:\"\")[text(\"link\")]]]")
  }

  @Test("Nested balanced quotes not allowed without escaping")
  func nestedBalancedQuotesNotAllowedWithoutEscaping() {
    let input = "[link](/url \"title \"and\" title\")"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link](/url \\\"title \\\"and\\\" title\\\")\")]]")
  }

  @Test("Using different quote type for nested quotes")
  func usingDifferentQuoteTypeForNestedQuotes() {
    let input = "[link](/url 'title \"and\" title')"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title \\\"and\\\" title\")[text(\"link\")]]]")
  }

  // MARK: - Whitespace in links

  @Test("Whitespace allowed around destination and title")
  func whitespaceAllowedAroundDestinationAndTitle() {
    let input = """
    [link](   /uri
      "title"  )
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"title\")[text(\"link\")]]]")
  }

  @Test("Whitespace not allowed between link text and parenthesis")
  func whitespaceNotAllowedBetweenLinkTextAndParenthesis() {
    let input = "[link] (/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link] (/uri)\")]]")
  }

  // MARK: - Link text with brackets

  @Test("Link text with balanced brackets")
  func linkTextWithBalancedBrackets() {
    let input = "[link [foo [bar]]](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link [foo [bar]]\")]]]")
  }

  @Test("Unbalanced brackets break link text")
  func unbalancedBracketsBreakLinkText() {
    let input = "[link] bar](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link] bar](/uri)\")]]")
  }

  @Test("Unbalanced opening bracket creates nested link")
  func unbalancedOpeningBracketCreatesNestedLink() {
    let input = "[link [bar](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[link \"),link(url:\"/uri\",title:\"\")[text(\"bar\")]]]")
  }

  @Test("Escaped bracket in link text")
  func escapedBracketInLinkText() {
    let input = "[link \\[bar](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link [bar\")]]]")
  }

  // MARK: - Link text with inline content

  @Test("Link text with inline formatting")
  func linkTextWithInlineFormatting() {
    let input = "[link *foo **bar** `#`*](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link \"),emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" \"),code(\"#\")]]]")
  }

  @Test("Link containing image")
  func linkContainingImage() {
    let input = "[![moon](moon.jpg)](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[image(url:\"moon.jpg\",alt:\"moon\",title:\"\")]]]")
  }

  // MARK: - Nested links not allowed

  @Test("Links may not contain other links")
  func linksMayNotContainOtherLinks() {
    let input = "[foo [bar](/uri)](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo \"),link(url:\"/uri\",title:\"\")[text(\"bar\")],text(\"](/uri)\")]]")
  }

  @Test("Complex nested link structure")
  func complexNestedLinkStructure() {
    let input = "[foo *[bar [baz](/uri)](/uri)*](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo \"),emphasis[text(\"[bar \"),link(url:\"/uri\",title:\"\")[text(\"baz\")],text(\"](/uri)\")],text(\"](/uri)\")]]")
  }

  @Test("Image with nested link structure")
  func imageWithNestedLinkStructure() {
    let input = "![[[foo](uri1)](uri2)](uri3)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[image(url:\"uri3\",alt:\"[foo](uri2)\",title:\"\")]]")
  }

  // MARK: - Precedence rules

  @Test("Link text grouping takes precedence over emphasis grouping")
  func linkTextGroupingTakesPrecedenceOverEmphasisGrouping() {
    let input = "*[foo*](/uri)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),link(url:\"/uri\",title:\"\")[text(\"foo*\")]]]")
  }

  @Test("Link text grouping with emphasis in destination")
  func linkTextGroupingWithEmphasisInDestination() {
    let input = "[foo *bar](baz*)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"baz*\",title:\"\")[text(\"foo *bar\")]]]")
  }

  @Test("Brackets not part of links do not take precedence")
  func bracketsNotPartOfLinksDoNotTakePrecedence() {
    let input = "*foo [bar* baz]"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo [bar\")],text(\" baz]\")]]")
  }

  // MARK: - HTML tags, code spans, autolinks precedence

  @Test("HTML tags group more tightly than link grouping")
  func htmlTagsGroupMoreTightlyThanLinkGrouping() {
    let input = "[foo <bar attr=\"](baz)\">"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo <bar attr=\\\"](baz)\\\">\")]]")
  }

  @Test("Code spans group more tightly than link grouping")
  func codeSpansGroupMoreTightlyThanLinkGrouping() {
    let input = "[foo`](/uri)`"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo\"),code(\"](/uri)\")]]")
  }

  @Test("Autolinks group more tightly than link grouping")
  func autolinksGroupMoreTightlyThanLinkGrouping() {
    let input = "[foo<http://example.com/?search=](uri)>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo\"),link(url:\"http://example.com/?search=%5D(uri)\",title:\"\")[text(\"http://example.com/?search=](uri)\")]]]")
  }

  // MARK: - Reference links - Full reference links

  @Test("Simple full reference link")
  func simpleFullReferenceLink() {
    let input = """
    [foo][bar]

    [bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]],reference(id:\"bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Full reference link with balanced brackets in text")
  func fullReferenceLinkWithBalancedBracketsInText() {
    let input = """
    [link [foo [bar]]][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link [foo [bar]]\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference link with escaped bracket in text")
  func fullReferenceLinkWithEscapedBracketInText() {
    let input = """
    [link \\[bar][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link [bar\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference link with inline formatting in text")
  func fullReferenceLinkWithInlineFormattingInText() {
    let input = """
    [link *foo **bar** `#`*][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link \"),emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" \"),code(\"#\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference link containing image")
  func fullReferenceLinkContainingImage() {
    let input = """
    [![moon](moon.jpg)][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[image(url:\"moon.jpg\",alt:\"moon\",title:\"\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference links cannot contain other links")
  func fullReferenceLinksCannotContainOtherLinks() {
    let input = """
    [foo [bar](/uri)][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo \"),link(url:\"/uri\",title:\"\")[text(\"bar\")],text(\"]\"),link(url:\"/uri\",title:\"\")[text(\"ref\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference link with nested emphasis and links")
  func fullReferenceLinkWithNestedEmphasisAndLinks() {
    let input = """
    [foo *bar [baz][ref]*][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo \"),emphasis[text(\"bar \"),link(url:\"/uri\",title:\"\")[text(\"baz\")]],text(\"]\"),link(url:\"/uri\",title:\"\")[text(\"ref\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  // MARK: - Reference link precedence

  @Test("Full reference link text grouping over emphasis")
  func fullReferenceLinkTextGroupingOverEmphasis() {
    let input = """
    *[foo*][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),link(url:\"/uri\",title:\"\")[text(\"foo*\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Full reference link text with emphasis marker")
  func fullReferenceLinkTextWithEmphasisMarker() {
    let input = """
    [foo *bar][ref]

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"foo *bar\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("HTML tags precedence over reference link grouping")
  func htmlTagsPrecedenceOverReferenceLinkGrouping() {
    let input = """
    [foo <bar attr="][ref]">

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo <bar attr=\\\"][ref]\\\">\")),reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Code spans precedence over reference link grouping")
  func codeSpansPrecedenceOverReferenceLinkGrouping() {
    let input = """
    [foo`][ref]`

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo\"),code(\"][ref]\")],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  @Test("Autolinks precedence over reference link grouping")
  func autolinksPrecedenceOverReferenceLinkGrouping() {
    let input = """
    [foo<http://example.com/?search=][ref]>

    [ref]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo\"),link(url:\"http://example.com/?search=%5D%5Bref%5D\",title:\"\")[text(\"http://example.com/?search=][ref]\")]],reference(id:\"ref\",url:\"/uri\",title:\"\")]")
  }

  // MARK: - Reference link matching

  @Test("Reference link matching is case-insensitive")
  func referenceLinkMatchingIsCaseInsensitive() {
    let input = """
    [foo][BaR]

    [bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]],reference(id:\"bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Unicode case fold is used for matching")
  func unicodeCaseFoldIsUsedForMatching() {
    let input = """
    [Толпой][Толпой] is a Russian word.

    [ТОЛПОЙ]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"Толпой\")],text(\" is a Russian word.\")],reference(id:\"ТОЛПОЙ\",url:\"/url\",title:\"\")]")
  }

  @Test("Consecutive internal whitespace treated as one space")
  func consecutiveInternalWhitespaceTreatedAsOneSpace() {
    let input = """
    [Foo
      bar]: /url

    [Baz][Foo bar]
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[reference(id:\"Foo bar\",url:\"/url\",title:\"\"),paragraph[link(url:\"/url\",title:\"\")[text(\"Baz\")]]]")
  }

  // MARK: - Reference link whitespace rules

  @Test("No whitespace allowed between link text and label")
  func noWhitespaceAllowedBetweenLinkTextAndLabel() {
    let input = """
    [foo] [bar]

    [bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo] \"),link(url:\"/url\",title:\"title\")[text(\"bar\")]],reference(id:\"bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("No newline allowed between link text and label")
  func noNewlineAllowedBetweenLinkTextAndLabel() {
    let input = """
    [foo]
    [bar]

    [bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo]\"),line_break(soft),link(url:\"/url\",title:\"title\")[text(\"bar\")]],reference(id:\"bar\",url:\"/url\",title:\"title\")]")
  }

  // MARK: - Multiple matching reference definitions

  @Test("First matching reference definition is used")
  func firstMatchingReferenceDefinitionIsUsed() {
    let input = """
    [foo]: /url1

    [foo]: /url2

    [bar][foo]
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[reference(id:\"foo\",url:\"/url1\",title:\"\"),reference(id:\"foo\",url:\"/url2\",title:\"\"),paragraph[link(url:\"/url1\",title:\"\")[text(\"bar\")]]]")
  }

  @Test("Matching performed on normalized strings not parsed content")
  func matchingPerformedOnNormalizedStringsNotParsedContent() {
    let input = """
    [bar][foo\\!]

    [foo!]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[bar][foo!]\")],reference(id:\"foo!\",url:\"/url\",title:\"\")]")
  }

  // MARK: - Link label constraints

  @Test("Link labels cannot contain unescaped brackets")
  func linkLabelsCannotContainUnescapedBrackets() {
    let input = """
    [foo][ref[]

    [ref[]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo][ref[]\")],paragraph[text(\"[ref[]: /uri\")]]")
  }

  @Test("Link labels with nested brackets")
  func linkLabelsWithNestedBrackets() {
    let input = """
    [foo][ref[bar]]

    [ref[bar]]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo][ref[bar]]\")],paragraph[text(\"[ref[bar]]: /uri\")]]")
  }

  @Test("Link labels with triple nested brackets")
  func linkLabelsWithTripleNestedBrackets() {
    let input = """
    [[[foo]]]

    [[[foo]]]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[[[foo]]]\")],paragraph[text(\"[[[foo]]]: /url\")]]")
  }

  @Test("Link labels can contain escaped brackets")
  func linkLabelsCanContainEscapedBrackets() {
    let input = """
    [foo][ref\\[]

    [ref\\[]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"foo\")]],reference(id:\"ref[\",url:\"/uri\",title:\"\")]")
  }

  @Test("Backslash at end of reference definition")
  func backslashAtEndOfReferenceDefinition() {
    let input = """
    [bar\\\\]: /uri

    [bar\\\\]
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[reference(id:\"bar\\\\\",url:\"/uri\",title:\"\"),paragraph[link(url:\"/uri\",title:\"\")[text(\"bar\\\\\")]]]")
  }

  @Test("Link label must contain at least one non-whitespace character")
  func linkLabelMustContainAtLeastOneNonWhitespaceCharacter() {
    let input = """
    []

    []: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[]\")],paragraph[text(\"[]: /uri\")]]")
  }

  @Test("Link label with only whitespace")
  func linkLabelWithOnlyWhitespace() {
    let input = """
    [
     ]

    [
     ]: /uri
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[\"),line_break(soft),text(\" ]\")],paragraph[text(\"[\"),line_break(soft),text(\" ]: /uri\")]]")
  }

  // MARK: - Collapsed reference links

  @Test("Simple collapsed reference link")
  func simpleCollapsedReferenceLink() {
    let input = """
    [foo][]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference link with formatting")
  func collapsedReferenceLinkWithFormatting() {
    let input = """
    [*foo* bar][]

    [*foo* bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[emphasis[text(\"foo\")],text(\" bar\")]],reference(id:\"*foo* bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference link labels are case-insensitive")
  func collapsedReferenceLinkLabelsAreCaseInsensitive() {
    let input = """
    [Foo][]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"Foo\")]],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference link no whitespace between brackets")
  func collapsedReferenceLinkNoWhitespaceBetweenBrackets() {
    let input = """
    [foo]
    []

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")],line_break(soft),text(\"[]\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  // MARK: - Shortcut reference links

  @Test("Simple shortcut reference link")
  func simpleShortcutReferenceLink() {
    let input = """
    [foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Shortcut reference link with formatting")
  func shortcutReferenceLinkWithFormatting() {
    let input = """
    [*foo* bar]

    [*foo* bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[emphasis[text(\"foo\")],text(\" bar\")]],reference(id:\"*foo* bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Shortcut reference link with double brackets")
  func shortcutReferenceLinkWithDoubleBrackets() {
    let input = """
    [[*foo* bar]]

    [*foo* bar]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[\"),link(url:\"/url\",title:\"title\")[emphasis[text(\"foo\")],text(\" bar\")],text(\"]\")],reference(id:\"*foo* bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Shortcut reference link with unmatched bracket")
  func shortcutReferenceLinkWithUnmatchedBracket() {
    let input = """
    [[bar [foo]

    [foo]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[[bar \"),link(url:\"/url\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url\",title:\"\")]")
  }

  @Test("Shortcut reference link labels are case-insensitive")
  func shortcutReferenceLinkLabelsAreCaseInsensitive() {
    let input = """
    [Foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"Foo\")]],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Space after shortcut reference link text is preserved")
  func spaceAfterShortcutReferenceLinkTextIsPreserved() {
    let input = """
    [foo] bar

    [foo]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")],text(\" bar\")],reference(id:\"foo\",url:\"/url\",title:\"\")]")
  }

  @Test("Escaped opening bracket avoids links")
  func escapedOpeningBracketAvoidsLinks() {
    let input = """
    \\[foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo]\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Link label ends with first closing bracket")
  func linkLabelEndsWithFirstClosingBracket() {
    let input = """
    [foo*]: /url

    *[foo*]
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[reference(id:\"foo*\",url:\"/url\",title:\"\"),paragraph[text(\"*\"),link(url:\"/url\",title:\"\")[text(\"foo*\")]]]")
  }

  // MARK: - Link precedence rules

  @Test("Full reference links take precedence over shortcut")
  func fullReferenceLinksTaskePrecedenceOverShortcut() {
    let input = """
    [foo][bar]

    [foo]: /url1
    [bar]: /url2
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url2\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url1\",title:\"\"),reference(id:\"bar\",url:\"/url2\",title:\"\")]")
  }

  @Test("Collapsed reference links take precedence over shortcut")
  func collapsedReferenceLinksTaskePrecedenceOverShortcut() {
    let input = """
    [foo][]

    [foo]: /url1
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url1\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url1\",title:\"\")]")
  }

  @Test("Inline links take precedence over reference links")
  func inlineLinksTaskePrecedenceOverReferenceLinks() {
    let input = """
    [foo]()

    [foo]: /url1
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url1\",title:\"\")]")
  }

  @Test("Reference link fallback when inline link invalid")
  func referenceLinkFallbackWhenInlineLinkInvalid() {
    let input = """
    [foo](not a link)

    [foo]: /url1
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url1\",title:\"\")[text(\"foo\")],text(\"(not a link)\")],reference(id:\"foo\",url:\"/url1\",title:\"\")]")
  }

  // MARK: - Complex reference link precedence

  @Test("Reference parsing precedence with multiple brackets")
  func referenceParsingPrecedenceWithMultipleBrackets() {
    let input = """
    [foo][bar][baz]

    [baz]: /url
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo]\"),link(url:\"/url\",title:\"\")[text(\"bar\")]],reference(id:\"baz\",url:\"/url\",title:\"\")]")
  }

  @Test("Reference parsing with defined bar")
  func referenceParsingWithDefinedBar() {
    let input = """
    [foo][bar][baz]

    [baz]: /url1
    [bar]: /url2
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[link(url:\"/url2\",title:\"\")[text(\"foo\")],link(url:\"/url1\",title:\"\")[text(\"baz\")]],reference(id:\"baz\",url:\"/url1\",title:\"\"),reference(id:\"bar\",url:\"/url2\",title:\"\")]")
  }

  @Test("Shortcut reference not parsed when followed by link label")
  func shortcutReferenceNotParsedWhenFollowedByLinkLabel() {
    let input = """
    [foo][bar][baz]

    [baz]: /url1
    [foo]: /url2
    """
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"[foo]\"),link(url:\"/url1\",title:\"\")[text(\"bar\")]],reference(id:\"baz\",url:\"/url1\",title:\"\"),reference(id:\"foo\",url:\"/url2\",title:\"\")]")
  }
}

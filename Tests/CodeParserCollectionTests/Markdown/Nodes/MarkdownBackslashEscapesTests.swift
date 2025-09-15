import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Backslash Escapes Tests - Spec 028")
struct MarkdownBackslashEscapesTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("ASCII punctuation characters can be backslash-escaped")
  func asciiPunctuationCharactersCanBeBackslashEscaped() {
    let input = ##"""
      \!\"\#\$\%\<\&\'\(\)\*\+\,\-\.\:\/\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~

      """##
    let result = parser.parse(input, language: language)

    let expectedSig = ##"document[paragraph[text("!"#$%<&'()*+,-.:/;<=>?@[\]^_`{|}~")]]"##
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslashes before non-punctuation characters treated as literal")
  func backslashesBeforeNonPunctuationCharactersTreatedAsLiteral() {
    let input = #"\→\A\a\ \3\φ\«"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[text("\→\A\a\ \3\φ\«")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Escaped characters lose their markdown meaning")
  func escapedCharactersLoseTheirMarkdownMeaning() {
    let input = ##"""
      \*not emphasized*
      \<br/> not a tag
      \[not a link](/foo)
      \`not code`
      1\. not a list
      \* not a list
      \# not a heading
      \[foo]: /url "not a reference"
      \&ouml; not a character entity
      """##
    let result = parser.parse(input, language: language)

    let expectedSig =
      ##"document[paragraph[text("*not emphasized*"),line_break(soft),text("<br/> not a tag"),line_break(soft),text("[not a link](/foo)"),line_break(soft),text("`not code`"),line_break(soft),text("1. not a list"),line_break(soft),text("* not a list"),line_break(soft),text("# not a heading"),line_break(soft),text("[foo]: /url "not a reference""),line_break(soft),text("&ouml; not a character entity")]]"##
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Escaped backslash allows following character to have markdown meaning")
  func escapedBackslashAllowsFollowingCharacterToHaveMarkdownMeaning() {
    let input = #"\\*emphasis*"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[text("\"),emphasis[text("emphasis")]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash at end of line creates hard line break")
  func backslashAtEndOfLineCreatesHardLineBreak() {
    let input = #"""
      foo\
      bar
      """#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[text("foo"),line_break(hard),text("bar")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in code spans")
  func backslashEscapesDoNotWorkInCodeSpans() {
    let input = #"`` \[\` ``"#
    let result = parser.parse(input, language: language)
    let expectedSig = #"document[paragraph[code("\[\`")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in indented code blocks")
  func backslashEscapesDoNotWorkInIndentedCodeBlocks() {
    let input = #"    \[\]"#
    let result = parser.parse(input, language: language)
    let expectedSig = #"document[code_block("\[\]\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in fenced code blocks")
  func backslashEscapesDoNotWorkInFencedCodeBlocks() {
    let input = #"""
      ~~~
      \[\]
      ~~~
      """#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[code_block("\[\]\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in autolinks")
  func backslashEscapesDoNotWorkInAutolinks() {
    let input = #"<http://example.com?find=\*>"#
    let result = parser.parse(input, language: language)

    let expectedSig =
      #"document[paragraph[link(url:"http://example.com?find=\*",title:"")[text("http://example.com?find=\*")]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes do not work in raw HTML")
  func backslashEscapesDoNotWorkInRawHTML() {
    let input = #"<a href="/bar\/)">"#
    let result = parser.parse(input, language: language)

    // Inline HTML tag <a> should be parsed as inline html inside a paragraph; backslashes are literal.
    let expectedSig = #"document[paragraph[html("<a href="/bar\/)"">")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes work in link URLs and titles")
  func backslashEscapesWorkInLinkURLsAndTitles() {
    let input = #"[foo](/bar\* "ti\*tle")"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[link(url:"/bar*",title:"ti*tle")[text("foo")]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes work in link references")
  func backslashEscapesWorkInLinkReferences() {
    let input = #"""
      [foo]

      [foo]: /bar\* "ti\*tle"
      """#
    let result = parser.parse(input, language: language)

    let expectedSig =
      #"document[paragraph[link(url:"/bar*",title:"ti*tle")[text("foo")]],reference(id:"foo",url:"/bar*",title:"ti*tle")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escapes work in fenced code block info strings")
  func backslashEscapesWorkInFencedCodeBlockInfoStrings() {
    let input = #"""
      ``` foo\+bar
      foo
      ```
      """#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[code_block(lang:"foo+bar","foo\#n")]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Multiple backslash escapes in single paragraph")
  func multipleBackslashEscapesInSingleParagraph() {
    let input = ##"This \* is \# not \[special\] text."##
    let result = parser.parse(input, language: language)

    // Should not contain any special markdown elements

    let expectedSig = #"document[paragraph[text("This * is # not [special] text.")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escape at beginning of line")
  func backslashEscapeAtBeginningOfLine() {
    let input = ##"\# This is not a heading"##
    let result = parser.parse(input, language: language)

    let expectedSig = ##"document[paragraph[text("# This is not a heading")]]"##
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escape preserves literal character in emphasis context")
  func backslashEscapePreservesLiteralCharacterInEmphasisContext() {
    let input = #"*This \* is still emphasis*"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[emphasis[text("This * is still emphasis")]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash before space character")
  func backslashBeforeSpaceCharacter() {
    let input = #"word\ word"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[text("word\ word")]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Backslash escape in link text")
  func backslashEscapeInLinkText() {
    let input = #"[foo\*bar](/url)"#
    let result = parser.parse(input, language: language)

    let expectedSig = #"document[paragraph[link(url:"/url",title:"")[text("foo*bar")]]]"#
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Sequential backslash escapes")
  func sequentialBackslashEscapes() {
    let input = #"\*text*"#
    let result = parser.parse(input, language: language)

    // First backslash escapes second, third escapes asterisk, last asterisk is literal

    let expectedSig = #"document[paragraph[text("*text*")]]"#
    #expect(sig(result.root) == expectedSig)
  }
}

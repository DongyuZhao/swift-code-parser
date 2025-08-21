import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Emphasis and Strong Emphasis Tests - Spec 031")
struct MarkdownEmphasisAndStrongEmphasisTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Rule 1: Single * can open emphasis iff it is part of a left-flanking delimiter run

  @Test("Basic emphasis with asterisks")
  func basicAsteriskEmphasis() {
    let input = "*foo bar*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo bar\")]]]")
  }

  @Test("Opening asterisk followed by whitespace does not create emphasis")
  func asteriskFollowedByWhitespace() {
    let input = "a * foo bar*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"a * foo bar*\")]]")
  }

  @Test("Opening asterisk preceded by alphanumeric and followed by punctuation does not create emphasis")
  func asteriskPrecededByAlphanumericFollowedByPunctuation() {
    let input = "a*\"foo\"*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"a*\\\"foo\\\"*\")]]")
  }

  @Test("Unicode nonbreaking spaces count as whitespace")
  func unicodeNonbreakingSpacesAsWhitespace() {
    let input = "* a *"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"* a *\")]]")
  }

  @Test("Intraword emphasis with asterisks is permitted")
  func intrawordAsteriskEmphasis() {
    let input = "foo*bar*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo\"),emphasis[text(\"bar\")]]]")
  }

  @Test("Intraword emphasis with asterisks and numbers")
  func intrawordAsteriskEmphasisWithNumbers() {
    let input = "5*6*78"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"5\"),emphasis[text(\"6\")],text(\"78\")]]")
  }

  // MARK: - Rule 2: Single _ can open emphasis with additional restrictions

  @Test("Basic emphasis with underscores")
  func basicUnderscoreEmphasis() {
    let input = "_foo bar_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo bar\")]]]")
  }

  @Test("Opening underscore followed by whitespace does not create emphasis")
  func underscoreFollowedByWhitespace() {
    let input = "_ foo bar_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_ foo bar_\")]]")
  }

  @Test("Opening underscore preceded by alphanumeric and followed by punctuation does not create emphasis")
  func underscorePrecededByAlphanumericFollowedByPunctuation() {
    let input = "a_\"foo\"_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"a_\\\"foo\\\"_\")]]")
  }

  @Test("Emphasis with underscores is not allowed inside words")
  func underscoreEmphasisNotAllowedInsideWords() {
    let input = "foo_bar_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo_bar_\")]]")
  }

  @Test("Underscore emphasis not allowed inside words with numbers")
  func underscoreEmphasisNotAllowedInsideWordsWithNumbers() {
    let input = "5_6_78"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"5_6_78\")]]")
  }

  @Test("Underscore emphasis not allowed inside words with Unicode")
  func underscoreEmphasisNotAllowedInsideWordsUnicode() {
    let input = "пристаням_стремятся_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"пристаням_стремятся_\")]]")
  }

  @Test("Right-flanking and left-flanking underscores do not generate emphasis")
  func rightFlankingLeftFlankingUnderscores() {
    let input = "aa_\"bb\"_cc"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"aa_\\\"bb\\\"_cc\")]]")
  }

  @Test("Emphasis with underscore when preceded by punctuation")
  func underscoreEmphasisPrecededByPunctuation() {
    let input = "foo-_(bar)_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo-\"),emphasis[text(\"(bar)\")]]]")
  }

  // MARK: - Rule 3: Single * can close emphasis iff it is part of a right-flanking delimiter run

  @Test("Closing delimiter does not match opening delimiter")
  func closingDelimiterDoesNotMatch() {
    let input = "_foo*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_foo*\")]]")
  }

  @Test("Closing asterisk preceded by whitespace does not close emphasis")
  func closingAsteriskPrecededByWhitespace() {
    let input = "*foo bar *"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*foo bar *\")]]")
  }

  @Test("Newline counts as whitespace for closing asterisk")
  func newlineCountsAsWhitespaceForClosingAsterisk() {
    let input = "*foo bar\n*"
    let result = parser.parse(input, language: language)

  #expect(sig(result.root) == "document[paragraph[text(\"*foo bar\"),line_break(soft),text(\"*\")]]")
  }

  @Test("Asterisk preceded by punctuation and followed by alphanumeric is not right-flanking")
  func asteriskPrecededByPunctuationFollowedByAlphanumeric() {
    let input = "*(*foo)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*(*foo)\")]]")
  }

  @Test("Nested emphasis with asterisks")
  func nestedEmphasisWithAsterisks() {
    let input = "*(*foo*)*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"(\"),emphasis[text(\"foo\")],text(\")\")]]]")
  }

  @Test("Intraword emphasis ending with asterisk")
  func intrawordEmphasisEndingWithAsterisk() {
    let input = "*foo*bar"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\")],text(\"bar\")]]")
  }

  // MARK: - Rule 4: Single _ can close emphasis with additional restrictions

  @Test("Closing underscore preceded by whitespace does not close emphasis")
  func closingUnderscorePrecededByWhitespace() {
    let input = "_foo bar _"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_foo bar _\")]]")
  }

  @Test("Underscore preceded by punctuation and followed by alphanumeric does not close emphasis")
  func underscorePrecededByPunctuationFollowedByAlphanumeric() {
    let input = "_(_foo)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_(_foo)\")]]")
  }

  @Test("Nested emphasis with underscores")
  func nestedEmphasisWithUnderscores() {
    let input = "_(_foo_)_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"(\"),emphasis[text(\"foo\")],text(\")\")]]]")
  }

  @Test("Intraword emphasis with underscores is disallowed")
  func intrawordEmphasisWithUnderscoresDisallowed() {
    let input = "_foo_bar"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_foo_bar\")]]")
  }

  @Test("Intraword emphasis with underscores and Unicode is disallowed")
  func intrawordEmphasisWithUnderscoresUnicodeDisallowed() {
    let input = "_пристаням_стремятся"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_пристаням_стремятся\")]]")
  }

  @Test("Underscore emphasis with internal underscores")
  func underscoreEmphasisWithInternalUnderscores() {
    let input = "_foo_bar_baz_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo_bar_baz\")]]]")
  }

  @Test("Underscore emphasis followed by punctuation")
  func underscoreEmphasisFollowedByPunctuation() {
    let input = "_(bar)_."
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"(bar)\")],text(\".\")]]")
  }

  // MARK: - Rule 5: Double ** can open strong emphasis iff it is part of a left-flanking delimiter run

  @Test("Basic strong emphasis with double asterisks")
  func basicDoubleAsteriskStrongEmphasis() {
    let input = "**foo bar**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo bar\")]]]")
  }

  @Test("Opening double asterisk followed by whitespace does not create strong emphasis")
  func doubleAsteriskFollowedByWhitespace() {
    let input = "** foo bar**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"** foo bar**\")]]")
  }

  @Test("Opening double asterisk preceded by alphanumeric and followed by punctuation does not create strong emphasis")
  func doubleAsteriskPrecededByAlphanumericFollowedByPunctuation() {
    let input = "a**\"foo\"**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"a**\\\"foo\\\"**\")]]")
  }

  @Test("Intraword strong emphasis with double asterisks is permitted")
  func intrawordDoubleAsteriskStrongEmphasis() {
    let input = "foo**bar**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo\"),strong[text(\"bar\")]]]")
  }

  // MARK: - Rule 6: Double __ can open strong emphasis with additional restrictions

  @Test("Basic strong emphasis with double underscores")
  func basicDoubleUnderscoreStrongEmphasis() {
    let input = "__foo bar__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo bar\")]]]")
  }

  @Test("Opening double underscore followed by whitespace does not create strong emphasis")
  func doubleUnderscoreFollowedByWhitespace() {
    let input = "__ foo bar__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__ foo bar__\")]]")
  }

  @Test("Newline counts as whitespace for double underscore")
  func newlineCountsAsWhitespaceForDoubleUnderscore() {
    let input = "__\nfoo bar__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__\nfoo bar__\")]]")
  }

  @Test("Opening double underscore preceded by alphanumeric and followed by punctuation does not create strong emphasis")
  func doubleUnderscorePrecededByAlphanumericFollowedByPunctuation() {
    let input = "a__\"foo\"__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"a__\\\"foo\\\"__\")]]")
  }

  @Test("Intraword strong emphasis with double underscores is forbidden")
  func intrawordDoubleUnderscoreStrongEmphasisForbidden() {
    let input = "foo__bar__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo__bar__\")]]")
  }

  @Test("Intraword strong emphasis with double underscores and numbers is forbidden")
  func intrawordDoubleUnderscoreStrongEmphasisWithNumbersForbidden() {
    let input = "5__6__78"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"5__6__78\")]]")
  }

  @Test("Intraword strong emphasis with double underscores and Unicode is forbidden")
  func intrawordDoubleUnderscoreStrongEmphasisUnicodeForbidden() {
    let input = "пристаням__стремятся__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"пристаням__стремятся__\")]]")
  }

  @Test("Double underscore strong emphasis with nested content")
  func doubleUnderscoreStrongEmphasisWithNestedContent() {
    let input = "__foo, __bar__, baz__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo, bar, baz\")]]]")
  }

  @Test("Double underscore strong emphasis preceded by punctuation")
  func doubleUnderscoreStrongEmphasisPrecededByPunctuation() {
    let input = "foo-__(bar)__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo-\"),strong[text(\"(bar)\")]]]")
  }

  // MARK: - Rule 7: Double ** can close strong emphasis iff it is part of a right-flanking delimiter run

  @Test("Closing double asterisk preceded by whitespace does not close strong emphasis")
  func closingDoubleAsteriskPrecededByWhitespace() {
    let input = "**foo bar **"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**foo bar **\")]]")
  }

  @Test("Double asterisk preceded by punctuation and followed by alphanumeric is not right-flanking")
  func doubleAsteriskPrecededByPunctuationFollowedByAlphanumeric() {
    let input = "**(**foo)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**(**foo)\")]]")
  }

  @Test("Nested strong and emphasis with double asterisks")
  func nestedStrongAndEmphasisWithDoubleAsterisks() {
    let input = "*(**foo**)*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"(\"),strong[text(\"foo\")],text(\")\")]]]")
  }

  @Test("Complex nested emphasis and strong emphasis")
  func complexNestedEmphasisAndStrongEmphasis() {
    let input = "**Gomphocarpus (*Gomphocarpus physocarpus*, syn. *Asclepias physocarpa*)**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"Gomphocarpus (\"),emphasis[text(\"Gomphocarpus physocarpus\")],text(\", syn. \"),emphasis[text(\"Asclepias physocarpa\")],text(\")\")]]]")
  }

  @Test("Strong emphasis with nested emphasis and quotes")
  func strongEmphasisWithNestedEmphasisAndQuotes() {
    let input = "**foo \"*bar*\" foo**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \\\"\"),emphasis[text(\"bar\")],text(\"\\\" foo\")]]]")
  }

  @Test("Intraword strong emphasis ending with double asterisk")
  func intrawordStrongEmphasisEndingWithDoubleAsterisk() {
    let input = "**foo**bar"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")],text(\"bar\")]]")
  }

  // MARK: - Rule 8: Double __ can close strong emphasis with additional restrictions

  @Test("Closing double underscore preceded by whitespace does not close strong emphasis")
  func closingDoubleUnderscorePrecededByWhitespace() {
    let input = "__foo bar __"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__foo bar __\")]]")
  }

  @Test("Double underscore preceded by punctuation and followed by alphanumeric does not close strong emphasis")
  func doubleUnderscorePrecededByPunctuationFollowedByAlphanumeric() {
    let input = "__(__foo)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__(__foo)\")]]")
  }

  @Test("Nested underscore strong emphasis")
  func nestedUnderscoreStrongEmphasis() {
    let input = "_(__foo__)_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"(\"),strong[text(\"foo\")],text(\")\")]]]")
  }

  @Test("Intraword strong emphasis with double underscores is forbidden for closing")
  func intrawordStrongEmphasisWithDoubleUnderscoresClosingForbidden() {
    let input = "__foo__bar"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__foo__bar\")]]")
  }

  @Test("Intraword strong emphasis with double underscores and Unicode is forbidden for closing")
  func intrawordStrongEmphasisWithDoubleUnderscoresUnicodeClosingForbidden() {
    let input = "__пристаням__стремятся"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__пристаням__стремятся\")]]")
  }

  @Test("Double underscore strong emphasis with internal double underscores")
  func doubleUnderscoreStrongEmphasisWithInternalDoubleUnderscores() {
    let input = "__foo__bar__baz__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo__bar__baz\")]]]")
  }

  @Test("Double underscore strong emphasis followed by punctuation")
  func doubleUnderscoreStrongEmphasisFollowedByPunctuation() {
    let input = "__(bar)__."
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"(bar)\")],text(\".\")]]")
  }

  // MARK: - Rule 9: Emphasis begins with delimiter that can open and ends with delimiter that can close

  @Test("Emphasis can contain links")
  func emphasisCanContainLinks() {
    let input = "*foo [bar](/url)*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),link(url:\"/url\",title:\"\")[text(\"bar\")]]]]")
  }

  @Test("Emphasis can span multiple lines")
  func emphasisCanSpanMultipleLines() {
    let input = "*foo\nbar*"
    let result = parser.parse(input, language: language)

  #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\"),line_break(soft),text(\"bar\")]]]")
  }

  @Test("Nested emphasis and strong emphasis within emphasis")
  func nestedEmphasisAndStrongEmphasisWithinEmphasis() {
    let input = "_foo __bar__ baz_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" baz\")]]]")
  }

  @Test("Nested emphasis within emphasis")
  func nestedEmphasisWithinEmphasis() {
    let input = "_foo _bar_ baz_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]]")
  }

  @Test("Complex nested emphasis structure")
  func complexNestedEmphasisStructure() {
    let input = "__foo_ bar_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[emphasis[text(\"foo\")],text(\" bar\")]]]")
  }

  @Test("Nested emphasis with asterisks")
  func nestedEmphasisWithAsterisksPattern() {
    let input = "*foo *bar**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),emphasis[text(\"bar\")]]]]")
  }

  @Test("Mixed emphasis and strong emphasis within emphasis")
  func mixedEmphasisAndStrongEmphasisWithinEmphasis() {
    let input = "*foo **bar** baz*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" baz\")]]]")
  }

  @Test("Continuous nested emphasis and strong emphasis")
  func continuousNestedEmphasisAndStrongEmphasis() {
    let input = "*foo**bar**baz*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\"),strong[text(\"bar\")],text(\"baz\")]]]")
  }

  @Test("Multiple asterisk rule prevents certain interpretations")
  func multipleAsteriskRulePreventsInterpretations() {
    let input = "*foo**bar*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo**bar\")]]]")
  }

  @Test("Triple asterisk strong emphasis within emphasis")
  func tripleAsteriskStrongEmphasisWithinEmphasis() {
    let input = "***foo** bar*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[strong[text(\"foo\")],text(\" bar\")]]]")
  }

  @Test("Strong emphasis within emphasis at end")
  func strongEmphasisWithinEmphasisAtEnd() {
    let input = "*foo **bar***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")]]]]")
  }

  @Test("Continuous strong emphasis within emphasis at end")
  func continuousStrongEmphasisWithinEmphasisAtEnd() {
    let input = "*foo**bar***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\"),strong[text(\"bar\")]]]]")
  }

  @Test("Multiple delimiter lengths create nested emphasis")
  func multipleDelimiterLengthsCreateNestedEmphasis() {
    let input = "foo***bar***baz"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo\"),emphasis[strong[text(\"bar\")]],text(\"baz\")]]")
  }

  @Test("Complex multiple asterisk pattern")
  func complexMultipleAsteriskPattern() {
    let input = "foo******bar*********baz"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo\"),strong[text(\"bar\")],text(\"***baz\")]]")
  }

  @Test("Indefinite levels of nesting are possible")
  func indefiniteLevelsOfNestingArePossible() {
    let input = "*foo **bar *baz* bim** bop*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),strong[text(\"bar \"),emphasis[text(\"baz\")],text(\" bim\")],text(\" bop\")]]]")
  }

  @Test("Emphasis with nested links")
  func emphasisWithNestedLinks() {
    let input = "*foo [*bar*](/url)*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),link(url:\"/url\",title:\"\")[emphasis[text(\"bar\")]]]]]")
  }

  @Test("Empty emphasis is not allowed")
  func emptyEmphasisIsNotAllowed() {
    let input = "** is not an empty emphasis"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"** is not an empty emphasis\")]]")
  }

  @Test("Empty strong emphasis is not allowed")
  func emptyStrongEmphasisIsNotAllowed() {
    let input = "**** is not an empty strong emphasis"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**** is not an empty strong emphasis\")]]")
  }

  // MARK: - Rule 10: Strong emphasis begins with delimiter that can open and ends with delimiter that can close

  @Test("Strong emphasis can contain links")
  func strongEmphasisCanContainLinks() {
    let input = "**foo [bar](/url)**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),link(url:\"/url\",title:\"\")[text(\"bar\")]]]]")
  }

  @Test("Strong emphasis can span multiple lines")
  func strongEmphasisCanSpanMultipleLines() {
    let input = "**foo\nbar**"
    let result = parser.parse(input, language: language)

  #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\"),line_break(soft),text(\"bar\")]]]")
  }

  @Test("Nested emphasis within strong emphasis")
  func nestedEmphasisWithinStrongEmphasis() {
    let input = "__foo _bar_ baz__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]]")
  }

  @Test("Nested strong emphasis collapses")
  func nestedStrongEmphasisCollapses() {
    let input = "__foo __bar__ baz__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo bar baz\")]]]")
  }

  @Test("Quadruple underscore collapses to strong emphasis")
  func quadrupleUnderscoreCollapsesToStrongEmphasis() {
    let input = "____foo__ bar__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo bar\")]]]")
  }

  @Test("Quadruple asterisk collapses to strong emphasis")
  func quadrupleAsteriskCollapsesToStrongEmphasis() {
    let input = "**foo **bar****"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo bar\")]]]")
  }

  @Test("Strong emphasis with nested emphasis and asterisks")
  func strongEmphasisWithNestedEmphasisAndAsterisks() {
    let input = "**foo *bar* baz**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]]")
  }

  @Test("Continuous strong emphasis with nested emphasis")
  func continuousStrongEmphasisWithNestedEmphasis() {
    let input = "**foo*bar*baz**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\"),emphasis[text(\"bar\")],text(\"baz\")]]]")
  }

  @Test("Emphasis within strong emphasis at beginning")
  func emphasisWithinStrongEmphasisAtBeginning() {
    let input = "***foo* bar**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[emphasis[text(\"foo\")],text(\" bar\")]]]")
  }

  @Test("Emphasis within strong emphasis at end")
  func emphasisWithinStrongEmphasisAtEnd() {
    let input = "**foo *bar***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")]]]]")
  }

  @Test("Complex multi-line nested strong emphasis")
  func complexMultiLineNestedStrongEmphasis() {
    let input = "**foo *bar **baz**\nbim* bop**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),emphasis[text(\"bar \"),strong[text(\"baz\")],text(\"\nbim\")],text(\" bop\")]]]")
  }

  @Test("Strong emphasis with nested links")
  func strongEmphasisWithNestedLinks() {
    let input = "**foo [*bar*](/url)**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo \"),link(url:\"/url\",title:\"\")[emphasis[text(\"bar\")]]]]]")
  }

  @Test("Empty emphasis with double underscore is not allowed")
  func emptyEmphasisWithDoubleUnderscoreIsNotAllowed() {
    let input = "__ is not an empty emphasis"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__ is not an empty emphasis\")]]")
  }

  @Test("Empty strong emphasis with quadruple underscore is not allowed")
  func emptyStrongEmphasisWithQuadrupleUnderscoreIsNotAllowed() {
    let input = "____ is not an empty strong emphasis"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"____ is not an empty strong emphasis\")]]")
  }

  // MARK: - Rule 11: Literal * cannot occur at beginning or end of *-delimited emphasis

  @Test("Three asterisks without content")
  func threeAsterisksWithoutContent() {
    let input = "foo ***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo ***\")]]")
  }

  @Test("Escaped asterisk within emphasis")
  func escapedAsteriskWithinEmphasis() {
    let input = "foo *\\**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),emphasis[text(\"*\")]]]")
  }

  @Test("Underscore within asterisk emphasis")
  func underscoreWithinAsteriskEmphasis() {
    let input = "foo *_*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),emphasis[text(\"_\")]]]")
  }

  @Test("Five asterisks without content")
  func fiveAsterisksWithoutContent() {
    let input = "foo *****"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo *****\")]]")
  }

  @Test("Escaped asterisk within strong emphasis")
  func escapedAsteriskWithinStrongEmphasis() {
    let input = "foo **\\***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),strong[text(\"*\")]]]")
  }

  @Test("Underscore within strong asterisk emphasis")
  func underscoreWithinStrongAsteriskEmphasis() {
    let input = "foo **_**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),strong[text(\"_\")]]]")
  }

  @Test("Unmatched asterisk delimiters create excess asterisks outside emphasis")
  func unmatchedAsteriskDelimitersCreateExcessAsterisksOutsideEmphasis() {
    let input = "**foo*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),emphasis[text(\"foo\")]]]")
  }

  @Test("Unmatched asterisk delimiters excess at end")
  func unmatchedAsteriskDelimitersExcessAtEnd() {
    let input = "*foo**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\")],text(\"*\")]]")
  }

  @Test("Triple asterisk with double asterisk creates excess")
  func tripleAsteriskWithDoubleAsteriskCreatesExcess() {
    let input = "***foo**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),strong[text(\"foo\")]]]")
  }

  @Test("Quadruple asterisk with single creates excess")
  func quadrupleAsteriskWithSingleCreatesExcess() {
    let input = "****foo*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"***\"),emphasis[text(\"foo\")]]]")
  }

  @Test("Double asterisk with triple creates excess")
  func doubleAsteriskWithTripleCreatesExcess() {
    let input = "**foo***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")],text(\"*\")]]")
  }

  @Test("Single asterisk with quadruple creates excess")
  func singleAsteriskWithQuadrupleCreatesExcess() {
    let input = "*foo****"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\")],text(\"***\")]]")
  }

  // MARK: - Rule 12: Literal _ cannot occur at beginning or end of _-delimited emphasis

  @Test("Three underscores without content")
  func threeUnderscoresWithoutContent() {
    let input = "foo ___"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo ___\")]]")
  }

  @Test("Escaped underscore within emphasis")
  func escapedUnderscoreWithinEmphasis() {
    let input = "foo _\\__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),emphasis[text(\"_\")]]]")
  }

  @Test("Asterisk within underscore emphasis")
  func asteriskWithinUnderscoreEmphasis() {
    let input = "foo _*_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),emphasis[text(\"*\")]]]")
  }

  @Test("Five underscores without content")
  func fiveUnderscoresWithoutContent() {
    let input = "foo _____"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo _____\")]]")
  }

  @Test("Escaped underscore within strong emphasis")
  func escapedUnderscoreWithinStrongEmphasis() {
    let input = "foo __\\___"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),strong[text(\"_\")]]]")
  }

  @Test("Asterisk within strong underscore emphasis")
  func asteriskWithinStrongUnderscoreEmphasis() {
    let input = "foo __*__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"foo \"),strong[text(\"*\")]]]")
  }

  @Test("Double underscore with single creates excess at beginning")
  func doubleUnderscoreWithSingleCreatesExcessAtBeginning() {
    let input = "__foo_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_\"),emphasis[text(\"foo\")]]]")
  }

  @Test("Unmatched underscore delimiters excess at end")
  func unmatchedUnderscoreDelimitersExcessAtEnd() {
    let input = "_foo__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\")],text(\"_\")]]")
  }

  @Test("Triple underscore with double creates excess")
  func tripleUnderscoreWithDoubleCreatesExcess() {
    let input = "___foo__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_\"),strong[text(\"foo\")]]]")
  }

  @Test("Quadruple underscore with single creates excess")
  func quadrupleUnderscoreWithSingleCreatesExcess() {
    let input = "____foo_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"___\"),emphasis[text(\"foo\")]]]")
  }

  @Test("Double underscore with triple creates excess")
  func doubleUnderscoreWithTripleCreatesExcess() {
    let input = "__foo___"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")],text(\"_\")]]")
  }

  @Test("Single underscore with quadruple creates excess")
  func singleUnderscoreWithQuadrupleCreatesExcess() {
    let input = "_foo____"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo\")],text(\"___\")]]")
  }

  // MARK: - Rule 13: Minimize nesting - prefer <strong> over <em><em>

  @Test("Double asterisk creates strong emphasis not nested emphasis")
  func doubleAsteriskCreatesStrongEmphasisNotNestedEmphasis() {
    let input = "**foo**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")]]]")
  }

  @Test("Mixed delimiters create nested emphasis")
  func mixedDelimitersCreateNestedEmphasis() {
    let input = "*_foo_*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[emphasis[text(\"foo\")]]]]")
  }

  @Test("Double underscore creates strong emphasis not nested emphasis")
  func doubleUnderscoreCreatesStrongEmphasisNotNestedEmphasis() {
    let input = "__foo__"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")]]]")
  }

  @Test("Mixed underscore and asterisk create nested emphasis")
  func mixedUnderscoreAndAsteriskCreateNestedEmphasis() {
    let input = "_*foo*_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[emphasis[text(\"foo\")]]]]")
  }

  @Test("Quadruple asterisk creates strong emphasis not nested")
  func quadrupleAsteriskCreatesStrongEmphasisNotNested() {
    let input = "****foo****"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")]]]")
  }

  @Test("Quadruple underscore creates strong emphasis not nested")
  func quadrupleUnderscoreCreatesStrongEmphasisNotNested() {
    let input = "____foo____"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")]]]")
  }

  @Test("Sextuple asterisk creates strong emphasis not nested")
  func sextupleAsteriskCreatesStrongEmphasisNotNested() {
    let input = "******foo******"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[strong[text(\"foo\")]]]")
  }

  // MARK: - Rule 14: Prefer <em><strong> over <strong><em>

  @Test("Triple asterisk creates emphasis containing strong emphasis")
  func tripleAsteriskCreatesEmphasisContainingStrongEmphasis() {
    let input = "***foo***"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[strong[text(\"foo\")]]]]")
  }

  @Test("Quintuple underscore creates emphasis containing strong emphasis")
  func quintupleUnderscoreCreatesEmphasisContainingStrongEmphasis() {
    let input = "_____foo_____"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[strong[text(\"foo\")]]]]")
  }

  // MARK: - Rule 15: First emphasis takes precedence when overlapping

  @Test("Overlapping emphasis first takes precedence")
  func overlappingEmphasisFirstTakesPrecedence() {
    let input = "*foo _bar* baz_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo _bar\")],text(\" baz_\")]]")
  }

  @Test("Overlapping strong and emphasis first takes precedence")
  func overlappingStrongAndEmphasisFirstTakesPrecedence() {
    let input = "*foo __bar *baz bim__ bam*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"foo \"),strong[text(\"bar *baz bim\")],text(\" bam\")]]]")
  }

  // MARK: - Rule 16: Shorter span takes precedence when same closing delimiter

  @Test("Shorter strong emphasis span takes precedence")
  func shorterStrongEmphasisSpanTakesPrecedence() {
    let input = "**foo **bar baz**"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**foo \"),strong[text(\"bar baz\")]]]")
  }

  @Test("Shorter emphasis span takes precedence")
  func shorterEmphasisSpanTakesPrecedence() {
    let input = "*foo *bar baz*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*foo \"),emphasis[text(\"bar baz\")]]]")
  }

  // MARK: - Rule 17: Code spans, links, images, HTML tags group more tightly than emphasis

  @Test("Links group more tightly than emphasis")
  func linksGroupMoreTightlyThanEmphasis() {
    let input = "*[bar*](/url)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),link(url:\"/url\",title:\"\")[text(\"bar*\")]]]")
  }

  @Test("Links with underscores group more tightly than emphasis")
  func linksWithUnderscoresGroupMoreTightlyThanEmphasis() {
    let input = "_foo [bar_](/url)"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"_foo \"),link(url:\"/url\",title:\"\")[text(\"bar_\")]]]")
  }

  @Test("HTML tags group more tightly than emphasis with asterisks")
  func htmlTagsGroupMoreTightlyThanEmphasisWithAsterisks() {
    let input = "*<img src=\"foo\" title=\"*\"/>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"*\"),html(\"<img src=\\\"foo\\\" title=\\\"*\\\"/>\")\n]]")
  }

  @Test("HTML tags group more tightly than strong emphasis with asterisks")
  func htmlTagsGroupMoreTightlyThanStrongEmphasisWithAsterisks() {
    let input = "**<a href=\"**\">"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**\"),html(\"<a href=\\\"**\\\">\")\n]]")
  }

  @Test("HTML tags group more tightly than strong emphasis with underscores")
  func htmlTagsGroupMoreTightlyThanStrongEmphasisWithUnderscores() {
    let input = "__<a href=\"__\">"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__\"),html(\"<a href=\\\"__\\\">\")\n]]")
  }

  @Test("Code spans group more tightly than emphasis with asterisks")
  func codeSpansGroupMoreTightlyThanEmphasisWithAsterisks() {
    let input = "*a `*`*"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"a \"),code(\"*\")]]]")
  }

  @Test("Code spans group more tightly than emphasis with underscores")
  func codeSpansGroupMoreTightlyThanEmphasisWithUnderscores() {
    let input = "_a `_`_"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"a \"),code(\"_\")]]]")
  }

  @Test("Autolinks group more tightly than strong emphasis with asterisks")
  func autolinksGroupMoreTightlyThanStrongEmphasisWithAsterisks() {
    let input = "**a<http://foo.bar/?q=**>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"**a\"),link(url:\"http://foo.bar/?q=**\",title:\"\")[text(\"http://foo.bar/?q=**\")]]]")
  }

  @Test("Autolinks group more tightly than strong emphasis with underscores")
  func autolinksGroupMoreTightlyThanStrongEmphasisWithUnderscores() {
    let input = "__a<http://foo.bar/?q=__>"
    let result = parser.parse(input, language: language)

    #expect(sig(result.root) == "document[paragraph[text(\"__a\"),link(url:\"http://foo.bar/?q=__\",title:\"\")[text(\"http://foo.bar/?q=__\")]]]")
  }
}

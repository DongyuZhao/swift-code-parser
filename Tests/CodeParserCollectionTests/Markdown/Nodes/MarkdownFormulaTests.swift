import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Formula Extension Tests")
struct MarkdownFormulaTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Spec F1: Inline formula parsing")
  func inlineFormula() {
    let input = "Euler: $e^{i\\pi}+1=0$"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[text(\"Euler: \"),formula]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F2: Block formula parsing")
  func blockFormula() {
    let input = "$$x=1$$"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[formula_block]"
  #expect(sig(result.root) == expectedSig)
  }

  // MARK: - Additional Coverage

  @Test("Spec F3: Backslash inline formula parsing")
  func backslashFormulas() {
    let input = #"Before \(a+b\) end"#
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[text(\"Before \"),formula,text(\" end\")]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F4: Backslash block formula \\[..\\]")
  func backslashBlock() {
    let input = #"\[ x^2 + y^2 \]"#
    let result = parser.parse(input, language: language)
  let expectedSig = "document[formula_block]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F5: Unclosed display $$ and \\[ ...")
  func unclosedDisplay() {
    let input = "$$x + 1\nNext line\n\\[ y+2"
    let result = parser.parse(input, language: language)
  // For unclosed display formula, we expect a single formula_block consuming until EOF.
  let expectedSig = "document[formula_block]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F6: Unclosed inline $x+1 should NOT form formula")
  func unclosedInline() {
    let input = "Text $x+1 and more"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[text(\"Text $x+1 and more\")]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F7: Whitespace invalid inline should not parse")
  func whitespaceInvalidInline() {
    let samples = ["$ x$", "$x $"]
    for s in samples {
      let result = parser.parse(s, language: language)
  let expectedSig = "document[paragraph[text(\"\(s)\")]]"
  #expect(sig(result.root) == expectedSig)
    }
  }

  @Test("Spec F8: Escaped dollar inside inline formula")
  func escapedDollar() {
    let input = #"$a\$b$"#
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[formula]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F9: Multiple inline formulas in one paragraph")
  func multipleInline() {
    let input = "A $x$ B $y^2$ C"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[text(\"A \"),formula,text(\" B \"),formula,text(\" C\")]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F10: Display formula with newline inside $$ .. $$")
  func displayWithNewline() {
    let input = "$$x^2 +\n y^2$$"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[formula_block]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F11: Adjacent inline formulas")
  func adjacentInline() {
    let input = "Text$A$B$C$Text"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[text(\"Text\"),formula,text(\"B\"),formula,text(\"Text\")]]"
  #expect(sig(result.root) == expectedSig)
  }

  @Test("Spec F12: Inline code containing dollar should not produce formula")
  func inlineCodeWithDollar() {
    let input = "`$a$` and $b$"
    let result = parser.parse(input, language: language)
  let expectedSig = "document[paragraph[code(\"$a$\"),text(\" and \"),formula]]"
  #expect(sig(result.root) == expectedSig)
  }
}

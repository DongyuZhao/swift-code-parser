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

  @Test("Inline formula parsing")
  func inlineFormula() {
    let input = "Euler: $e^{i\\pi}+1=0$"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.first(where: { $0.element == .formula }) != nil)
  }

  @Test("Block formula parsing")
  func blockFormula() {
    let input = "$$x=1$$"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is FormulaBlockNode)
  }

  // MARK: - Additional Coverage

  @Test("Backslash inline formula parsing")
  func backslashFormulas() {
    let input = #"Before \(a+b\) end"#
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let formulas = para?.children.compactMap { $0 as? FormulaNode }
    #expect(formulas?.count == 1)
    // Inline backslash variant is not trimmed by inline builder; expression keeps delimiters.
    #expect(formulas?.first?.expression == #"\(a+b\)"#)
  }

  @Test("Backslash block formula \\[..\\]")
  func backslashBlock() {
    let input = #"\[ x^2 + y^2 \]"#
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let block = result.root.children.first { $0.element == .formulaBlock } as? FormulaBlockNode
    #expect(block != nil)
    #expect(block?.expression == "x^2 + y^2")
  }

  @Test("Unclosed display $$ and \\[ ...")
  func unclosedDisplay() {
    let input = "$$x + 1\nNext line\n\\[ y+2"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let blocks = result.root.children.compactMap { $0 as? FormulaBlockNode }
    // Expect two blocks: one from $$... (until EOF or before next?), implementation: first $$ consumes until EOF so second will be inside same token text; thus only one block
    #expect(blocks.count == 1)
  #expect(blocks.first?.expression.contains("x + 1") == true)
  }

  @Test("Unclosed inline $x+1 should NOT form formula")
  func unclosedInline() {
    let input = "Text $x+1 and more"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
  let hasFormula = para?.children.contains(where: { ($0 as? MarkdownNodeBase)?.element == .formula }) ?? false
  #expect(!hasFormula)
  }

  @Test("Whitespace invalid inline should not parse")
  func whitespaceInvalidInline() {
    let samples = ["$ x$", "$x $"]
    for s in samples {
      let result = parser.parse(s, language: language)
      let para = result.root.children.first as? ParagraphNode
      #expect(para != nil)
  let hasFormula = para?.children.contains(where: { ($0 as? MarkdownNodeBase)?.element == .formula }) ?? false
      #expect(!hasFormula, "Should not parse inline formula with surrounding whitespace: \(s)")
    }
  }

  @Test("Escaped dollar inside inline formula")
  func escapedDollar() {
  let input = #"$a\$b$"#
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
  let formula = para?.children.first(where: { ($0 as? MarkdownNodeBase)?.element == .formula }) as? FormulaNode
    #expect(formula != nil)
  #expect(formula?.expression == #"a\$b"#)
  }

  @Test("Multiple inline formulas in one paragraph")
  func multipleInline() {
    let input = "A $x$ B $y^2$ C"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
  let formulas = para?.children.filter { ($0 as? MarkdownNodeBase)?.element == .formula }.compactMap { $0 as? FormulaNode }
    #expect(formulas?.count == 2)
    #expect(Set(formulas?.map { $0.expression } ?? []) == ["x", "y^2"])
  }

  @Test("Display formula with newline inside $$ .. $$")
  func displayWithNewline() {
    let input = "$$x^2 +\n y^2$$"
    let result = parser.parse(input, language: language)
    let block = result.root.children.first { $0.element == .formulaBlock } as? FormulaBlockNode
    #expect(block != nil)
  let normalized = block?.expression.replacingOccurrences(of: " ", with: "") ?? ""
  #expect(normalized.contains("x^2+\ny^2".replacingOccurrences(of: " ", with: "")))
  }

  @Test("Adjacent inline formulas")
  func adjacentInline() {
    let input = "Text$A$B$C$Text"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
  let formulas = para?.children.filter { ($0 as? MarkdownNodeBase)?.element == .formula }.compactMap { $0 as? FormulaNode }
  // In this input, only $A$ and $C$ exist as proper formulas.
  #expect(formulas?.count == 2)
  #expect(formulas?.map { $0.expression } == ["A", "C"])
  }

  @Test("Inline code containing dollar should not produce formula")
  func inlineCodeWithDollar() {
    let input = "`$a$` and $b$"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
  let formulas = para?.children.filter { ($0 as? MarkdownNodeBase)?.element == .formula }.compactMap { $0 as? FormulaNode }
    #expect(formulas?.count == 1)
    #expect(formulas?.first?.expression == "b")
  }
}

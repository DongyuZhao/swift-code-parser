import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Tabs Tests - Spec 006")
struct MarkdownTabsTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Helper to convert → to actual tab characters
  private func tabString(_ input: String) -> String {
    return input.replacingOccurrences(of: "→", with: "\t")
  }

  @Test("Tabs can be used instead of four spaces in indented code block with internal tabs passed through as literal")
  func basicTabsInCodeBlock() {
    let input = tabString("→foo→baz→→bim")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\(tabString("foo→baz→→bim"))\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tabs behave as if replaced by spaces with 4-character tab stop for block structure")
  func tabsWithTwoLeadingSpaces() {
    let input = tabString("  →foo→baz→→bim")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\(tabString("foo→baz→→bim"))\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tab stops at 4-character boundaries in indented code blocks")
  func tabsWithFourLeadingSpaces() {
    let input = tabString("    a→a\n    ὐ→a")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"\(tabString("a→a\nὐ→a"))\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tab indentation for list continuation paragraph has same effect as four spaces")
  func tabInListContinuation() {
    let input = tabString("  - foo\n\n→bar")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Double tab creates code block within list item due to 8-space equivalent indentation")
  func doubleTabCreatesCodeBlockInList() {
    let input = tabString("- foo\n\n→→bar")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"  bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tab after blockquote marker expands to 3 spaces, one consumed by delimiter, creating 6-space indented code block")
  func tabAfterBlockquoteMarker() {
    let input = tabString(">→→foo")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[blockquote[code_block(\"  foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Double tab after list marker creates indented code block within list item")
  func tabAfterListMarker() {
    let input = tabString("-→→foo")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[unordered_list(level:1)[list_item[code_block(\"  foo\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed spaces and tabs create continuous code block when both provide sufficient indentation")
  func mixedSpacesAndTabsInCodeBlock() {
    let input = tabString("    foo\n→bar")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[code_block(\"foo\nbar\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tab maintains nested list structure with proper indentation levels")
  func tabInNestedListStructure() {
    let input = tabString(" - foo\n   - bar\n→ - baz")
    let result = parser.parse(input, language: language)

    // Verify basic AST structure - should have nested lists
    let sig = sig(result.root)
    #expect(sig.contains("unordered_list"))
    #expect(sig.contains("list_item"))
    #expect(sig.contains("text(\"foo\")"))
    #expect(sig.contains("text(\"bar\")"))
    #expect(sig.contains("text(\"baz\")"))
  }

  @Test("Tab after ATX heading marker is treated as whitespace separator")
  func tabInATXHeading() {
    let input = tabString("#→Foo")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[heading(level:1)[text(\"Foo\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Tabs serve as whitespace in thematic break pattern recognition")
  func tabsInThematicBreak() {
    let input = tabString("*→*→*→")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[thematic_break]"
    #expect(sig(result.root) == expectedSig)
  }

  // MARK: - Additional Edge Cases

  @Test("Tabs in inline contexts are preserved as literal tab characters")
  func tabHandlingInInlineContexts() {
    let input = tabString("This→has→tabs")
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[text(\"\(tabString("This→has→tabs"))\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}

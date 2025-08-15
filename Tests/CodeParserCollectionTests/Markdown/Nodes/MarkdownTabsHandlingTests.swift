import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Tabs handling (Strict)")
struct MarkdownTabsHandlingTests {
  private let h = MarkdownTestHarness()
  // Spec 1: leading tab opens indented code block
  @Test("Spec 1: Tab at line start -> indented code block with preserved tabs")
  func spec1() {
    let input = "\tfoo\tbaz\t\tbim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == nil || code.language?.isEmpty == true)
    #expect(code.source == "foo\tbaz\t\tbim")
    #expect(sig(result.root) == "document[code_block(\"foo\\tbaz\\t\\tbim\")]")
  }

  // Spec 2: two spaces then tab -> still code block
  @Test("Spec 2: Two spaces then tab -> indented code block")
  func spec2() {
    let input = "  \tfoo\tbaz\t\tbim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "foo\tbaz\t\tbim")
    #expect(sig(result.root) == "document[code_block(\"foo\\tbaz\\t\\tbim\")]")
  }

  // Spec 3: visual alignment with tabs across lines
  @Test("Spec 3: Tabs inside indented code block across lines")
  func spec3() {
    let input = "    a\ta\n    ὐ\ta\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "a\ta\nὐ\ta")
    #expect(sig(result.root) == "document[code_block(\"a\\ta\\nὐ\\ta\")]")
  }

  // Spec 4: list with tab-indented following paragraph
  @Test("Spec 4: List item then tab-indented paragraph inside list item")
  func spec4() {
    let input = "  - foo\n\n\tbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    // Expect two paragraphs inside the list item: "foo" and "bar"
    let paras = li.children.compactMap { $0 as? ParagraphNode }
    #expect(paras.count == 2)
    #expect((paras[0].children.first as? TextNode)?.content == "foo")
    #expect((paras[1].children.first as? TextNode)?.content == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]")
  }

  // Spec 5: nested code block inside list because of two leading tabs on second block line
  @Test("Spec 5: List item then a fenced indented code block by tabs")
  func spec5() {
    let input = "- foo\n\n\t\tbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    // Expect paragraph "foo" then a CodeBlock with source "  bar" (two spaces in HTML), but our node keeps raw text without visual expansion
    #expect(li.children.count == 2)
    guard let para = li.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in LI")
      return
    }
    #expect((para.children.first as? TextNode)?.content == "foo")
    guard let code = li.children.last as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode in LI")
      return
    }
    // Per spec, content has two leading spaces after tab expansion inside list/code context
    #expect(code.source == "  bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"  bar\")]]]")
  }

  // Spec 6: blockquote then tab-indented code
  @Test("Spec 6: Blockquote line with tab leading to indented code")
  func spec6() {
    let input = ">\t\tfoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let code = bq.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode inside blockquote")
      return
    }
    #expect(code.source == "  foo")
    #expect(sig(result.root) == "document[blockquote[code_block(\"  foo\")]]")
  }

  // Spec 7: list marker then tab-indented code block within list item
  @Test("Spec 7: List item with tab-indented code block")
  func spec7() {
    let input = "-\t\tfoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    guard let code = li.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode in list item")
      return
    }
    #expect(code.source == "  foo")
  #expect(sig(result.root) == "document[unordered_list(level:1)[list_item[code_block(\"  foo\")]]]")
  }

  // Spec 8: first line 4 spaces, next line a tab -> same code block
  @Test("Spec 8: Mixed spaces and tab form one indented code block")
  func spec8() {
    let input = "    foo\n\tbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "foo\nbar")
    #expect(sig(result.root) == "document[code_block(\"foo\\nbar\")]")
  }

  // Spec 9: nested lists with a tab-indent on third level
  @Test("Spec 9: Nested lists with tab indentation at third level")
  func spec9() {
    let input = " - foo\n   - bar\n\t - baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Verify exact nested UL/LI structure: foo -> bar -> baz
    guard let ul1 = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected outer UL")
      return
    }
    #expect(ul1.children.count == 1)
    guard let li1 = ul1.children.first as? ListItemNode else {
      Issue.record("Expected LI level 1")
      return
    }
    // First LI has a paragraph 'foo' and a nested UL
    guard let p1 = li1.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph in LI1")
      return
    }
    #expect((p1.children.first as? TextNode)?.content == "foo")
    guard let ul2 = li1.children.last as? UnorderedListNode else {
      Issue.record("Expected nested UL in LI1")
      return
    }
    #expect(ul2.children.count == 1)
    guard let li2 = ul2.children.first as? ListItemNode else {
      Issue.record("Expected LI level 2")
      return
    }
    guard let p2 = li2.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph in LI2")
      return
    }
    #expect((p2.children.first as? TextNode)?.content == "bar")
    guard let ul3 = li2.children.last as? UnorderedListNode else {
      Issue.record("Expected nested UL in LI2")
      return
    }
    #expect(ul3.children.count == 1)
    guard let li3 = ul3.children.first as? ListItemNode else {
      Issue.record("Expected LI level 3")
      return
    }
    guard let p3 = li3.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph in LI3")
      return
    }
    #expect((p3.children.first as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")],unordered_list(level:3)[list_item[paragraph[text(\"baz\")]]]]]]]]"
    )
  }

  // Spec 10: ATX heading with tab between marker and text
  @Test("Spec 10: Tab after '#' still forms ATX heading")
  func spec10() {
    let input = "#\tFoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h1 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    #expect((h1.children.first as? TextNode)?.content == "Foo")
    #expect(sig(result.root) == "document[heading(level:1)[text(\"Foo\")]]")
  }

  // Spec 11: thematic break with tabs between markers
  @Test("Spec 11: Thematic break with tabs between markers")
  func spec11() {
    let input = "*\t*\t*\t\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }
}

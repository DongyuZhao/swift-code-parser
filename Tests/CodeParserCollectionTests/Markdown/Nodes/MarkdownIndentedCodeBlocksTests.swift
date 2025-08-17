import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Indented Code Blocks")
struct MarkdownIndentedCodeBlocksTests {
  private let h = MarkdownTestHarness()

  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
  }

  // 77: basic indented code block (strip 4 spaces baseline, preserve remaining)
  @Test("Spec 77: simple indented code block")
  func spec77() {
    let input = "    a simple\n      indented code block\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "a simple\n  indented code block")
    #expect(sig(result.root) == "document[code_block(\"a simple\\n  indented code block\")]")
  }

  // 78: list with second paragraph indented 4 spaces (not code)
  @Test("Spec 78: list item with second paragraph (no code block)")
  func spec78() {
    let input = "  - foo\n\n    bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 1)
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = li.children.compactMap { $0 as? ParagraphNode }
    #expect(paras.count == 2)
    if paras.count == 2 {
      #expect(innerText(paras[0]) == "foo")
      #expect(innerText(paras[1]) == "bar")
    }
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]")
  }

  // 79: ordered list item with nested unordered list
  @Test("Spec 79: ordered list with nested unordered list")
  func spec79() {
    let input = "1.  foo\n\n    - bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.children.count == 1)
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(li.children.first is ParagraphNode)
    #expect(li.children.contains { $0 is UnorderedListNode })
    if let p = li.children.first as? ParagraphNode { #expect(innerText(p) == "foo") }
    if let ul = li.children.first(where: { $0 is UnorderedListNode }) as? UnorderedListNode,
      let li2 = ul.children.first as? ListItemNode,
      let p2 = li2.children.first as? ParagraphNode
    {
      #expect(innerText(p2) == "bar")
    }
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")]]]]]]"
    )
  }

  // 80: everything stays literal inside an indented code block
  @Test("Spec 80: indented code block preserves HTML, emphasis, list markers")
  func spec80() {
    let input = "    <a/>\n    *hi*\n\n    - one\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "<a/>\n*hi*\n\n- one")
    #expect(sig(result.root) == "document[code_block(\"<a/>\\n*hi*\\n\\n- one\")]")
  }

  // 81: preserve blank lines inside code block
  @Test("Spec 81: code block with multiple blank lines preserved")
  func spec81() {
    let input = "    chunk1\n\n    chunk2\n  \n \n \n    chunk3\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "chunk1\n\nchunk2\n\n\n\nchunk3")
    #expect(sig(result.root) == "document[code_block(\"chunk1\\n\\nchunk2\\n\\n\\n\\nchunk3\")]")
  }

  // 82: internal indentation beyond 4 spaces retained after baseline removal
  @Test("Spec 82: internal indentation retained")
  func spec82() {
    let input = "    chunk1\n      \n      chunk2\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "chunk1\n  \n  chunk2")
    #expect(sig(result.root) == "document[code_block(\"chunk1\\n  \\n  chunk2\")]")
  }

  // 83: an indented line cannot interrupt a paragraph
  @Test("Spec 83: 4-space indented line as paragraph continuation")
  func spec83() {
    let input = "Foo\n    bar\n\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "Foo\nbar")
    #expect(sig(result.root) == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"bar\")]]")
  }

  // 84: code block followed by a paragraph
  @Test("Spec 84: code block then paragraph")
  func spec84() {
    let input = "    foo\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let code = result.root.children[0] as? CodeBlockNode {
      #expect(code.source == "foo")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    if let p = result.root.children[1] as? ParagraphNode {
      #expect(innerText(p) == "bar")
    } else {
      Issue.record("Expected ParagraphNode")
    }
    #expect(sig(result.root) == "document[code_block(\"foo\"),paragraph[text(\"bar\")]]")
  }

  // 85: headings interleaved with code blocks and hr
  @Test("Spec 85: h1, code, h2, code, hr")
  func spec85() {
    let input = "# Heading\n    foo\nHeading\n------\n    foo\n----\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 5)
    #expect(result.root.children[0] is HeaderNode)
    if let code1 = result.root.children[1] as? CodeBlockNode {
      #expect(code1.source == "foo")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    if let h2 = result.root.children[2] as? HeaderNode {
      #expect(h2.level == 2)
    } else {
      Issue.record("Expected HeaderNode")
    }
    if let code2 = result.root.children[3] as? CodeBlockNode {
      #expect(code2.source == "foo")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    #expect(result.root.children[4] is ThematicBreakNode)
    #expect(
      sig(result.root)
        == "document[heading(level:1)[text(\"Heading\")],code_block(\"foo\"),heading(level:2)[text(\"Heading\")],code_block(\"foo\"),thematic_break]"
    )
  }

  // 86: different indentation depths inside code block
  @Test("Spec 86: lines with >=8 and 4 spaces in same code block")
  func spec86() {
    let input = "        foo\n    bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "    foo\nbar")
    #expect(sig(result.root) == "document[code_block(\"    foo\\nbar\")]")
  }

  // 87: blank lines with indentation collapse to empty lines inside code
  @Test("Spec 87: code block around blank lines")
  func spec87() {
    let input = "\n    \n    foo\n    \n\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "foo")
    #expect(sig(result.root) == "document[code_block(\"foo\")]")
  }

  // 88: trailing spaces retained inside code block
  @Test("Spec 88: trailing spaces preserved in code block")
  func spec88() {
    let input = "    foo  \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "foo  ")
    #expect(sig(result.root) == "document[code_block(\"foo  \")]")
  }
}

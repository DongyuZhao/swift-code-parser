import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Paragraphs (Strict)")
struct MarkdownParagraphsTests {
  private let h = MarkdownTestHarness()
  // Uses shared childrenTypes/sig helpers from TestUtils

  // 189
  @Test("Spec 189: Two paragraphs separated by a blank line")
  func spec189() {
    let input = "aaa\n\nbbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    // Exact children for each paragraph: single Text node
    #expect(p1.children.count == 1)
    #expect((p1.children.first as? TextNode)?.content == "aaa")
    #expect(p2.children.count == 1)
    #expect((p2.children.first as? TextNode)?.content == "bbb")
    #expect(sig(result.root) == "document[paragraph[text(\"aaa\")],paragraph[text(\"bbb\")]]")
  }

  // 190
  @Test("Spec 190: Paragraphs separated by a blank line; newlines preserved inside")
  func spec190() {
    let input = "aaa\nbbb\n\nccc\nddd\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    // Each paragraph should be: Text, soft break, Text
    #expect(p1.children.count == 3)
    #expect((p1.children[0] as? TextNode)?.content == "aaa")
    #expect((p1.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p1.children[2] as? TextNode)?.content == "bbb")
    #expect(p2.children.count == 3)
    #expect((p2.children[0] as? TextNode)?.content == "ccc")
    #expect((p2.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p2.children[2] as? TextNode)?.content == "ddd")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")],paragraph[text(\"ccc\"),line_break(soft),text(\"ddd\")]]"
    )
  }

  // 191
  @Test("Spec 191: Multiple blank lines still separate paragraphs")
  func spec191() {
    let input = "aaa\n\n\nbbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    #expect(p1.children.count == 1)
    #expect((p1.children.first as? TextNode)?.content == "aaa")
    #expect(p2.children.count == 1)
    #expect((p2.children.first as? TextNode)?.content == "bbb")
  }

  // 192
  @Test("Spec 192: Up to three leading spaces are ignored in paragraphs")
  func spec192() {
    let input = "  aaa\n bbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Exact inline sequence: Text("aaa"), soft line break, Text("bbb")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "aaa")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bbb")
  }

  // 193
  @Test("Spec 193: Indented continuation lines do not start code block after paragraph line")
  func spec193() {
    let input = "aaa\n             bbb\n                                       ccc\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Exact inline sequence: Text("aaa"), soft break, Text("bbb"), soft break, Text("ccc"). No code blocks.
    #expect(p.children.count == 5)
    #expect((p.children[0] as? TextNode)?.content == "aaa")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bbb")
    #expect((p.children[3] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[4] as? TextNode)?.content == "ccc")
  }

  // 194
  @Test("Spec 194: Three leading spaces on first line are ignored")
  func spec194() {
    let input = "   aaa\nbbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Expect Text("aaa"), soft break, Text("bbb")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "aaa")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bbb")
    #expect(sig(result.root) == "document[paragraph[text(\"aaa\"),line_break(soft),text(\"bbb\")]]")
  }

  // 195
  @Test("Spec 195: Four leading spaces start an indented code block")
  func spec195() {
    let input = "    aaa\nbbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa")
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected trailing ParagraphNode")
      return
    }
    #expect(p.children.count == 1)
    #expect((p.children.first as? TextNode)?.content == "bbb")
    #expect(sig(result.root) == "document[code_block(\"aaa\"),paragraph[text(\"bbb\")]]")
  }

  // 196
  @Test("Spec 196: Two or more trailing spaces force a hard line break")
  func spec196() {
    let input = "aaa     \nbbb     \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "aaa")
    #expect((p.children[1] as? LineBreakNode)?.variant == .hard)
    #expect((p.children[2] as? TextNode)?.content == "bbb")
    #expect(sig(result.root) == "document[paragraph[text(\"aaa\"),line_break(hard),text(\"bbb\")]]")
  }

  // 197
  @Test("Spec 197: Blank lines are ignored; paragraph and heading only")
  func spec197() {
    let input = "  \n\naaa\n  \n\n# aaa\n\n  \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected first ParagraphNode")
      return
    }
    #expect(p.children.count == 1)
    #expect((p.children.first as? TextNode)?.content == "aaa")
    guard let h1 = result.root.children.last as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    #expect(innerText(h1) == "aaa")
    #expect(
      sig(result.root) == "document[paragraph[text(\"aaa\")],heading(level:1)[text(\"aaa\")]]")
  }

}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Block Quotes (Strict)")
struct MarkdownBlockQuotesTests {
  private let h = MarkdownTestHarness()

  // Helpers
  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
  }
  // childrenTypes and sig moved to shared TestUtils

  // 206
  @Test("Spec 206: Basic block quote with heading and paragraph")
  func spec206() {
    let input = "> # Foo\n> bar\n> baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 2)
    guard let h1 = bq.children[0] as? HeaderNode,
      let p = bq.children[1] as? ParagraphNode
    else {
      Issue.record("Expected heading then paragraph")
      return
    }
    #expect(h1.level == 1)
    #expect(innerText(h1) == "Foo")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),line_break(soft),text(\"baz\")]]]"
    )
  }

  // 207
  @Test("Spec 207: Block quote without space after > also works")
  func spec207() {
    let input = "># Foo\n>bar\n> baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 2)
    guard let h1 = bq.children[0] as? HeaderNode,
      let p = bq.children[1] as? ParagraphNode
    else {
      Issue.record("Expected heading then paragraph")
      return
    }
    #expect(h1.level == 1)
    #expect(innerText(h1) == "Foo")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),line_break(soft),text(\"baz\")]]]"
    )
  }

  // 208
  @Test("Spec 208: Block quote with indentation before >")
  func spec208() {
    let input = "   > # Foo\n   > bar\n > baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 2)
    guard let h1 = bq.children[0] as? HeaderNode,
      let p = bq.children[1] as? ParagraphNode
    else {
      Issue.record("Expected heading then paragraph")
      return
    }
    #expect(h1.level == 1)
    #expect(innerText(h1) == "Foo")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),line_break(soft),text(\"baz\")]]]"
    )
  }

  // 209
  @Test("Spec 209: Four-space indentation -> code block, not block quote")
  func spec209() {
    let input = "    > # Foo\n    > bar\n    > baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "> # Foo\n> bar\n> baz")
    #expect(sig(result.root) == "document[code_block(\"> # Foo\\n> bar\\n> baz\")]")
  }

  // 210
  @Test("Spec 210: Lazy continuation lines included in block quote")
  func spec210() {
    let input = "> # Foo\n> bar\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 2)
    guard let h1 = bq.children[0] as? HeaderNode,
      let p = bq.children[1] as? ParagraphNode
    else {
      Issue.record("Expected heading then paragraph")
      return
    }
    #expect(h1.level == 1)
    #expect(innerText(h1) == "Foo")
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[heading(level:1)[text(\"Foo\")],paragraph[text(\"bar\"),line_break(soft),text(\"baz\")]]]"
    )
  }

  // 211
  @Test("Spec 211: Multiple lazy lines accumulate in one paragraph")
  func spec211() {
    let input = "> bar\nbaz\n> foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 1)
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 5)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect((p.children[3] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[4] as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"bar\"),line_break(soft),text(\"baz\"),line_break(soft),text(\"foo\")]]]"
    )
  }

  // 212
  @Test("Spec 212: Thematic break breaks out of block quote")
  func spec212() {
    let input = "> foo\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let hr = result.root.children[1] as? ThematicBreakNode else {
      Issue.record("Expected ThematicBreakNode")
      return
    }
    _ = hr  // assert presence only
    #expect(bq.children.count == 1)
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "foo")
    #expect(sig(result.root) == "document[blockquote[paragraph[text(\"foo\")]],thematic_break]")
  }

  // 213
  @Test("Spec 213: List inside block quote and following top-level list")
  func spec213() {
    let input = "> - foo\n- bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let ul1 = bq.children.first as? UnorderedListNode else {
      Issue.record("Expected inner UnorderedListNode")
      return
    }
    #expect(ul1.children.count == 1)
    guard let li1 = ul1.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(findNodes(in: li1, ofType: ParagraphNode.self).count == 1)
    #expect(findNodes(in: li1, ofType: TextNode.self).first?.content == "foo")
    guard let ul2 = result.root.children[1] as? UnorderedListNode else {
      Issue.record("Expected top-level UnorderedListNode")
      return
    }
    #expect(ul2.children.count == 1)
    guard let li2 = ul2.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(findNodes(in: li2, ofType: TextNode.self).first?.content == "bar")
    #expect(
      sig(result.root)
  == "document[blockquote[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 214
  @Test("Spec 214: Indented code inside BQ; top-level code block after")
  func spec214() {
    let input = ">     foo\n    bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let code1 = bq.children.first as? CodeBlockNode else {
      Issue.record("Expected inner CodeBlockNode")
      return
    }
    #expect(code1.source == "foo")
    guard let code2 = result.root.children[1] as? CodeBlockNode else {
      Issue.record("Expected top-level CodeBlockNode")
      return
    }
    #expect(code2.source == "bar")
    #expect(sig(result.root) == "document[blockquote[code_block(\"foo\")],code_block(\"bar\")]")
  }

  // 215
  @Test("Spec 215: Fenced code inside BQ empty; outside paragraph and empty code")
  func spec215() {
    let input = "> ```\nfoo\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let bq = result.root.children[0] as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let codeIn = bq.children.first as? CodeBlockNode else {
      Issue.record("Expected inner CodeBlockNode")
      return
    }
    #expect(codeIn.source.isEmpty)
    guard let p = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "foo")
    guard let codeOut = result.root.children[2] as? CodeBlockNode else {
      Issue.record("Expected trailing CodeBlockNode")
      return
    }
    #expect(codeOut.source.isEmpty)
    #expect(
      sig(result.root)
        == "document[blockquote[code_block(\"\")],paragraph[text(\"foo\")],code_block(\"\")]")
  }

  // 216
  @Test("Spec 216: Lazy continuation not forming list inside BQ")
  func spec216() {
    let input = "> foo\n    - bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "foo")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "- bar")
    #expect(findNodes(in: bq, ofType: UnorderedListNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"foo\"),line_break(soft),text(\"- bar\")]]]")
  }

  // 217
  @Test("Spec 217: Empty block quote")
  func spec217() {
    let input = ">\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.isEmpty)
    #expect(sig(result.root) == "document[blockquote]")
  }

  // 218
  @Test("Spec 218: Only blank quoted lines -> empty block quote")
  func spec218() {
    let input = ">\n>  \n> \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.isEmpty)
    #expect(sig(result.root) == "document[blockquote]")
  }

  // 219
  @Test("Spec 219: Blank quoted lines allowed within BQ with text")
  func spec219() {
    let input = ">\n> foo\n>  \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 1)
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "foo")
    #expect(sig(result.root) == "document[blockquote[paragraph[text(\"foo\")]]]")
  }

  // 220
  @Test("Spec 220: Separate block quotes with blank line between")
  func spec220() {
    let input = "> foo\n\n> bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq1 = result.root.children[0] as? BlockquoteNode,
      let bq2 = result.root.children[1] as? BlockquoteNode
    else {
      Issue.record("Expected two BlockquoteNodes")
      return
    }
    #expect(innerText(bq1) == "foo")
    #expect(innerText(bq2) == "bar")
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"foo\")]],blockquote[paragraph[text(\"bar\")]]]")
  }

  // 221
  @Test("Spec 221: Two quoted lines -> one paragraph in one BQ")
  func spec221() {
    let input = "> foo\n> bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "foo")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bar")
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"foo\"),line_break(soft),text(\"bar\")]]]")
  }

  // 222
  @Test("Spec 222: Blank quoted line splits paragraphs within one BQ")
  func spec222() {
    let input = "> foo\n>\n> bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.count == 2)
    guard let p1 = bq.children[0] as? ParagraphNode,
      let p2 = bq.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs in BQ")
      return
    }
    #expect(innerText(p1) == "foo")
    #expect(innerText(p2) == "bar")
    #expect(
      sig(result.root) == "document[blockquote[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]")
  }

  // 223
  @Test("Spec 223: Paragraph then block quote")
  func spec223() {
    let input = "foo\n> bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p = result.root.children[0] as? ParagraphNode,
      let bq = result.root.children[1] as? BlockquoteNode
    else {
      Issue.record("Expected Paragraph then Blockquote")
      return
    }
    #expect(innerText(p) == "foo")
    #expect(innerText(bq) == "bar")
    #expect(
      sig(result.root) == "document[paragraph[text(\"foo\")],blockquote[paragraph[text(\"bar\")]]]")
  }

  // 224
  @Test("Spec 224: Thematic break splits two block quotes")
  func spec224() {
    let input = "> aaa\n***\n> bbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let bq1 = result.root.children[0] as? BlockquoteNode,
      let hr = result.root.children[1] as? ThematicBreakNode,
      let bq2 = result.root.children[2] as? BlockquoteNode
    else {
      Issue.record("Expected BQ, HR, BQ")
      return
    }
    _ = hr
    #expect(innerText(bq1) == "aaa")
    #expect(innerText(bq2) == "bbb")
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"aaa\")]],thematic_break,blockquote[paragraph[text(\"bbb\")]]]"
    )
  }

  // 225
  @Test("Spec 225: Lazy continuation after quoted line stays in BQ")
  func spec225() {
    let input = "> bar\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let p = bq.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "bar")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"bar\"),line_break(soft),text(\"baz\")]]]")
  }

  // 226
  @Test("Spec 226: Blank line after BQ ends it; following paragraph outside")
  func spec226() {
    let input = "> bar\n\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected BQ then paragraph")
      return
    }
    #expect(innerText(bq) == "bar")
    #expect(innerText(p2) == "baz")
    #expect(
      sig(result.root) == "document[blockquote[paragraph[text(\"bar\")]],paragraph[text(\"baz\")]]")
  }

  // 227
  @Test("Spec 227: Blank quoted line terminates paragraph inside BQ; next para outside")
  func spec227() {
    let input = "> bar\n>\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected BQ then paragraph")
      return
    }
    #expect(innerText(bq) == "bar")
    #expect(innerText(p2) == "bar")
    #expect(
      sig(result.root) == "document[blockquote[paragraph[text(\"bar\")]],paragraph[text(\"bar\")]]")
  }

  // 228
  @Test("Spec 228: Triple-nested BQ with lazy continuation")
  func spec228() {
    let input = "> > > foo\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq1 = result.root.children.first as? BlockquoteNode,
      let bq2 = bq1.children.first as? BlockquoteNode,
      let bq3 = bq2.children.first as? BlockquoteNode
    else {
      Issue.record("Expected triple-nested blockquotes")
      return
    }
    guard let p = bq3.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode at deepest level")
      return
    }
    #expect(p.children.count == 3)
    #expect((p.children[0] as? TextNode)?.content == "foo")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bar")
    #expect(
      sig(result.root)
        == "document[blockquote[blockquote[blockquote[paragraph[text(\"foo\"),line_break(soft),text(\"bar\")]]]]]"
    )
  }

  // 229
  @Test("Spec 229: Mixed quoting levels produce nested BQ with combined paragraph")
  func spec229() {
    let input = ">>> foo\n> bar\n>>baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq1 = result.root.children.first as? BlockquoteNode,
      let bq2 = bq1.children.first as? BlockquoteNode,
      let bq3 = bq2.children.first as? BlockquoteNode
    else {
      Issue.record("Expected triple-nested blockquotes")
      return
    }
    guard let p = bq3.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode at deepest level")
      return
    }
    #expect(p.children.count == 5)
    #expect((p.children[0] as? TextNode)?.content == "foo")
    #expect((p.children[1] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[2] as? TextNode)?.content == "bar")
    #expect((p.children[3] as? LineBreakNode)?.variant == .soft)
    #expect((p.children[4] as? TextNode)?.content == "baz")
    #expect(
      sig(result.root)
        == "document[blockquote[blockquote[blockquote[paragraph[text(\"foo\"),line_break(soft),text(\"bar\"),line_break(soft),text(\"baz\")]]]]]"
    )
  }

  // 230
  @Test("Spec 230: Indented code vs not code in separate BQs")
  func spec230() {
    let input = ">     code\n\n>    not code\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq1 = result.root.children[0] as? BlockquoteNode,
      let bq2 = result.root.children[1] as? BlockquoteNode
    else {
      Issue.record("Expected two BlockquoteNodes")
      return
    }
    guard let code = bq1.children.first as? CodeBlockNode else {
      Issue.record("Expected inner CodeBlockNode")
      return
    }
    #expect(code.source == "code")
    guard let p = bq2.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in second BQ")
      return
    }
    #expect(innerText(p) == "not code")
    #expect(
      sig(result.root)
        == "document[blockquote[code_block(\"code\")],blockquote[paragraph[text(\"not code\")]]]")
  }

}

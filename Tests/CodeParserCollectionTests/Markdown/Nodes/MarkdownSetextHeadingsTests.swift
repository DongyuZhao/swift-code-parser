import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Setext Headings")
struct MarkdownSetextHeadingsTests {
  private let h = MarkdownTestHarness()

  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
  }

  // 50: basic setext h1/h2 with emphasis inline
  @Test("Spec 50: setext h1/h2 with emphasis")
  func spec50() {
    let input = "Foo *bar*\n=========\n\nFoo *bar*\n---------\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    // First H1
    guard let h1 = result.root.children[0] as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    #expect(findNodes(in: h1, ofType: EmphasisNode.self).count == 1)
    if let em = findNodes(in: h1, ofType: EmphasisNode.self).first,
      let t = findNodes(in: em, ofType: TextNode.self).first
    {
      #expect(t.content == "bar")
    }
    // Second H2
    guard let h2 = result.root.children[1] as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h2.level == 2)
    #expect(findNodes(in: h2, ofType: EmphasisNode.self).count == 1)
    if let em = findNodes(in: h2, ofType: EmphasisNode.self).first,
      let t = findNodes(in: em, ofType: TextNode.self).first
    {
      #expect(t.content == "bar")
    }
    #expect(
      sig(result.root)
        == "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\")]],heading(level:2)[text(\"Foo \"),emphasis[text(\"bar\")]]]"
    )
  }

  // 51: emphasis spans newline within heading content
  @Test("Spec 51: emphasis across newline in setext h1")
  func spec51() {
    let input = "Foo *bar\nbaz*\n====\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h1 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    if let em = findNodes(in: h1, ofType: EmphasisNode.self).first,
      let t = findNodes(in: em, ofType: TextNode.self).first
    {
      #expect(t.content == "bar\nbaz")
    }
    #expect(
      sig(result.root) == "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\\nbaz\")]]]"
    )
  }

  // 52: leading spaces and trailing tab still form heading
  @Test("Spec 52: indentation and trailing whitespace allowed in setext h1")
  func spec52() {
    let input = "  Foo *bar\nbaz*\t\n====\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h1 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    if let em = findNodes(in: h1, ofType: EmphasisNode.self).first,
      let t = findNodes(in: em, ofType: TextNode.self).first
    {
      #expect(t.content == "bar\nbaz")
    }
    #expect(
      sig(result.root) == "document[heading(level:1)[text(\"Foo \"),emphasis[text(\"bar\\nbaz\")]]]"
    )
  }

  // 53: long underline => h2; single '=' => h1
  @Test("Spec 53: long hyphen line h2, single '=' h1")
  func spec53() {
    let input = "Foo\n-------------------------\n\nFoo\n=\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let h2 = result.root.children[0] as? HeaderNode { #expect(h2.level == 2) }
    if let h1 = result.root.children[1] as? HeaderNode { #expect(h1.level == 1) }
    #expect(
      sig(result.root)
        == "document[heading(level:2)[text(\"Foo\")],heading(level:1)[text(\"Foo\")]]")
  }

  // 54: up to 3 leading spaces allowed on both lines
  @Test("Spec 54: leading spaces allowed (2x h2, then h1)")
  func spec54() {
    let input = "   Foo\n---\n\n  Foo\n-----\n\n  Foo\n  ===\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    if let a = result.root.children[0] as? HeaderNode { #expect(a.level == 2) }
    if let b = result.root.children[1] as? HeaderNode { #expect(b.level == 2) }
    if let c = result.root.children[2] as? HeaderNode { #expect(c.level == 1) }
    #expect(
      sig(result.root)
        == "document[heading(level:2)[text(\"Foo\")],heading(level:2)[text(\"Foo\")],heading(level:1)[text(\"Foo\")]]"
    )
  }

  // 55: indented (4 spaces) => code block; then a separate hr
  @Test("Spec 55: indented text/underline => code block; then hr")
  func spec55() {
    let input = "    Foo\n    ---\n\n    Foo\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let code = result.root.children[0] as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "Foo\n---\n\nFoo")
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(sig(result.root) == "document[code_block(\"Foo\\n---\\n\\nFoo\"),thematic_break]")
  }

  // 56: trailing spaces on underline are allowed
  @Test("Spec 56: underline with trailing spaces => h2")
  func spec56() {
    let input = "Foo\n   ----      \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let h2 = result.root.children.first as? HeaderNode {
      #expect(h2.level == 2)
    } else {
      Issue.record("Expected HeaderNode")
    }
    #expect(sig(result.root) == "document[heading(level:2)[text(\"Foo\")]]")
  }

  // 57: 4-space indented underline does not count => paragraph
  @Test("Spec 57: 4-space indented underline => paragraph literal")
  func spec57() {
    let input = "Foo\n    ---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "Foo\n---")
    #expect(sig(result.root) == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"---\")]]")
  }

  // 58: spaces within underline break heading rule
  @Test("Spec 58: spaces in underline => not a heading")
  func spec58() {
    let input = "Foo\n= =\n\nFoo\n--- -\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    if let p1 = result.root.children[0] as? ParagraphNode { #expect(innerText(p1) == "Foo\n= =") }
    if let p2 = result.root.children[1] as? ParagraphNode { #expect(innerText(p2) == "Foo") }
    #expect(result.root.children[2] is ThematicBreakNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"= =\")],paragraph[text(\"Foo\")],thematic_break]"
    )
  }

  // 59: trailing double space on content line still heading
  @Test("Spec 59: content with trailing spaces => h2 Foo")
  func spec59() {
    let input = "Foo  \n-----\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h2 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h2.level == 2)
    if let t = findNodes(in: h2, ofType: TextNode.self).first { #expect(t.content == "Foo") }
    #expect(sig(result.root) == "document[heading(level:2)[text(\"Foo\")]]")
  }

  // 60: backslash at end of content line is literal
  @Test("Spec 60: backslash at EOL kept in h2 content")
  func spec60() {
    let input = "Foo\\\n----\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h2 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    if let t = findNodes(in: h2, ofType: TextNode.self).first { #expect(t.content == "Foo\\") }
    #expect(sig(result.root) == "document[heading(level:2)[text(\"Foo\\\\\")]]")
  }

  // 61: tricky cases with backticks and HTML attributes across lines
  @Test("Spec 61: tricky backtick/HTML split into h2 + p + h2 + p")
  func spec61() {
    let input = "`Foo\n----\n`\n\n<a title=\"a lot\n---\nof dashes\"/>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 4)
    // 1) h2 with content `Foo
    guard let h2a = result.root.children[0] as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    if let t = findNodes(in: h2a, ofType: TextNode.self).first { #expect(t.content == "`Foo") }
    // 2) paragraph: a sole backtick
    if let p1 = result.root.children[1] as? ParagraphNode { #expect(innerText(p1) == "`") }
    // 3) h2 from the HTML line up to the 'a lot'
    guard let h2b = result.root.children[2] as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    // The heading content might be parsed as TextNode or HTMLNode; accept either as long as content matches exactly
    let h2bText = findNodes(in: h2b, ofType: TextNode.self).first?.content
    let h2bHTML = findNodes(in: h2b, ofType: HTMLNode.self).first?.content
    #expect(h2bText == "<a title=\"a lot" || h2bHTML == "<a title=\"a lot")
    // 4) trailing paragraph with the rest
    if let p2 = result.root.children[3] as? ParagraphNode {
      #expect(innerText(p2) == "of dashes\"/>")
    }
    #expect(
      sig(result.root)
        == "document[heading(level:2)[text(\"`Foo\")],paragraph[text(\"`\")],heading(level:2)[text(\"<a title=\\\"a lot\")],paragraph[text(\"of dashes\\\"/>\")]]"
    )
  }

  // 62: '---' following a blockquote line becomes hr, not heading
  @Test("Spec 62: blockquote + hr")
  func spec62() {
    let input = "> Foo\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is BlockquoteNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(sig(result.root) == "document[blockquote[paragraph[text(\"Foo\")]],thematic_break]")
  }

  // 63: lazy continuation keeps === inside blockquote paragraph
  @Test("Spec 63: '===' stays inside blockquote paragraph")
  func spec63() {
    let input = "> foo\nbar\n===\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    if let p = bq.children.first as? ParagraphNode { #expect(innerText(p) == "foo\nbar\n===") }
    #expect(findNodes(in: result.root, ofType: HeaderNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[blockquote[paragraph[text(\"foo\"),line_break(soft),text(\"bar\"),line_break(soft),text(\"===\")]]]"
    )
  }

  // 64: list item then hr
  @Test("Spec 64: list then hr")
  func spec64() {
    let input = "- Foo\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]]],thematic_break]")
  }

  // 65: multiline content in setext heading
  @Test("Spec 65: multiline h2 content")
  func spec65() {
    let input = "Foo\nBar\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h2 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h2.level == 2)
    #expect(innerText(h2) == "FooBar")
    // Allow a line break between words in underlying text nodes
    let texts = findNodes(in: h2, ofType: TextNode.self).map { $0.content }
    #expect(texts == ["Foo", "Bar"])  // structure check
    #expect(sig(result.root) == "document[heading(level:2)[text(\"Foo\"),text(\"Bar\")]]")
  }

  // 66: hr + two h2 + paragraph
  @Test("Spec 66: hr, h2 Foo, h2 Bar, then paragraph Baz")
  func spec66() {
    let input = "---\nFoo\n---\nBar\n---\nBaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 4)
    #expect(result.root.children[0] is ThematicBreakNode)
    if let h2a = result.root.children[1] as? HeaderNode { #expect(h2a.level == 2) }
    if let h2b = result.root.children[2] as? HeaderNode { #expect(h2b.level == 2) }
    if let p = result.root.children[3] as? ParagraphNode { #expect(innerText(p) == "Baz") }
    #expect(
      sig(result.root)
        == "document[thematic_break,heading(level:2)[text(\"Foo\")],heading(level:2)[text(\"Bar\")],paragraph[text(\"Baz\")]]"
    )
  }

  // 67: missing content line => paragraph literal
  @Test("Spec 67: '====' alone => paragraph")
  func spec67() {
    let input = "\n====\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let p = result.root.children.first as? ParagraphNode { #expect(innerText(p) == "====") }
    #expect(sig(result.root) == "document[paragraph[text(\"====\")]]")
  }

  // 68: two hrs
  @Test("Spec 68: two thematic breaks")
  func spec68() {
    let input = "---\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children.allSatisfy { $0 is ThematicBreakNode })
    #expect(sig(result.root) == "document[thematic_break,thematic_break]")
  }

  // 69: list then hr (variant)
  @Test("Spec 69: list item then hr")
  func spec69() {
    let input = "- foo\n-----\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],thematic_break]")
  }

  // 70: indented paragraph => code block, then hr
  @Test("Spec 70: indented paragraph becomes code block, then hr")
  func spec70() {
    let input = "    foo\n---\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let code = result.root.children[0] as? CodeBlockNode {
      #expect(code.source == "foo")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(sig(result.root) == "document[code_block(\"foo\"),thematic_break]")
  }

  // 71: blockquote then hr
  @Test("Spec 71: blockquote then hr")
  func spec71() {
    let input = "> foo\n-----\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is BlockquoteNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(sig(result.root) == "document[blockquote[paragraph[text(\"foo\")]],thematic_break]")
  }

  // 72: escaped '>' means literal text; then h2
  @Test("Spec 72: escaped '>' line forms h2 content: > foo")
  func spec72() {
    let input = "\\> foo\n------\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h2 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    if let t = findNodes(in: h2, ofType: TextNode.self).first { #expect(t.content == "> foo") }
    #expect(sig(result.root) == "document[heading(level:2)[text(\"> foo\")]]")
  }

  // 73: paragraph, h2, paragraph
  @Test("Spec 73: p, h2, p")
  func spec73() {
    let input = "Foo\n\nbar\n---\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ParagraphNode)
    #expect(result.root.children[1] is HeaderNode)
    #expect(result.root.children[2] is ParagraphNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\")],heading(level:2)[text(\"bar\")],paragraph[text(\"baz\")]]"
    )
  }

  // 74: p, hr, p (since underline separated by blank lines)
  @Test("Spec 74: p, hr, p")
  func spec74() {
    let input = "Foo\nbar\n\n---\n\nBaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ParagraphNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(result.root.children[2] is ParagraphNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"bar\")],thematic_break,paragraph[text(\"Baz\")]]"
    )
  }

  // 75: p, hr, p (thematic break of '* * *')
  @Test("Spec 75: p, hr('* * *'), p")
  func spec75() {
    let input = "Foo\nbar\n* * *\nBaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ParagraphNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(result.root.children[2] is ParagraphNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"bar\")],thematic_break,paragraph[text(\"Baz\")]]"
    )
  }

  // 76: escaped underline => single paragraph with all lines
  @Test("Spec 76: escaped '---' => all in one paragraph")
  func spec76() {
    let input = "Foo\nbar\n\\---\nBaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "Foo\nbar\n---\nBaz")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\"),line_break(soft),text(\"bar\"),line_break(soft),text(\"---\"),line_break(soft),text(\"Baz\")]]"
    )
  }

}

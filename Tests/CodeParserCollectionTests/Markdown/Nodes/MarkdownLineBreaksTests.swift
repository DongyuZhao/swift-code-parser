import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Line Breaks")
struct MarkdownLineBreaksTests {
  private let h = MarkdownTestHarness()

  // 653 - Hard line break by two spaces
  @Test("Spec 653: Hard line break by two spaces")
  func spec653() {
    let input = "foo  \nbaz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"baz\")]]")
  }

  // 654 - Hard line break by backslash
  @Test("Spec 654: Hard line break by backslash")
  func spec654() {
    let input = "foo\\\nbaz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"baz\")]]")
  }

  // 655 - Hard line break by 7 spaces
  @Test("Spec 655: Hard line break by 7 spaces")
  func spec655() {
    let input = "foo       \nbaz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"baz\")]]")
  }

  // 656 - Hard line break (two spaces) followed by indented next line
  @Test("Spec 656: Hard line break two spaces then indented next line")
  func spec656() {
    let input = "foo  \n     bar\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"bar\")]]")
  }

  // 657 - Hard line break by backslash followed by indented next line
  @Test("Spec 657: Hard line break by backslash then indented next line")
  func spec657() {
    let input = "foo\\\n     bar\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"bar\")]]")
  }

  // 658 - Hard line break inside emphasis (two spaces)
  @Test("Spec 658: Hard line break inside emphasis (two spaces)")
  func spec658() {
    let input = "*foo  \nbar*\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let em = p.children.first as? EmphasisNode
    else {
      Issue.record("Expected emphasis paragraph")
      return
    }
    #expect(childrenTypes(em) == [.text, .lineBreak, .text])
    #expect(
      sig(r.root) == "document[paragraph[emphasis[text(\"foo\"),line_break(hard),text(\"bar\")]]]")
  }

  // 659 - Hard line break inside emphasis (backslash)
  @Test("Spec 659: Hard line break inside emphasis (backslash)")
  func spec659() {
    let input = "*foo\\\nbar*\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let em = p.children.first as? EmphasisNode
    else {
      Issue.record("Expected emphasis paragraph")
      return
    }
    #expect(childrenTypes(em) == [.text, .lineBreak, .text])
    #expect(
      sig(r.root) == "document[paragraph[emphasis[text(\"foo\"),line_break(hard),text(\"bar\")]]]")
  }

  // 660 - Hard line break inside code span by two spaces
  @Test("Spec 660: Code span across a hard break by two spaces")
  func spec660() {
    let input = "`code  \nspan`\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let code = p.children.first as? InlineCodeNode
    else {
      Issue.record("Expected InlineCode in paragraph")
      return
    }
    #expect(code.code == "code   span")
    #expect(sig(r.root) == "document[paragraph[code(\"code   span\")]]")
  }

  // 661 - Code span across a hard break by backslash
  @Test("Spec 661: Code span across a hard break by backslash")
  func spec661() {
    let input = "`code\\\nspan`\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let code = p.children.first as? InlineCodeNode
    else {
      Issue.record("Expected InlineCode in paragraph")
      return
    }
    #expect(code.code == "code\\ span")
    #expect(sig(r.root) == "document[paragraph[code(\"code\\\\ span\")]]")
  }

  // 662 - HTML inline with two-space hard break inside attribute value
  @Test("Spec 662: Inline HTML with two-space hard break inside attribute")
  func spec662() {
    let input = "<a href=\"foo  \nbar\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let h1 = p.children.first as? HTMLNode
    else {
      Issue.record("Expected inline HTML")
      return
    }
    #expect(h1.content == "<a href=\"foo  \nbar\">")
    #expect(sig(r.root) == "document[paragraph[html]]")
  }

  // 663 - Inline HTML with backslash hard break inside attribute value
  @Test("Spec 663: Inline HTML with backslash hard break inside attribute")
  func spec663() {
    let input = "<a href=\"foo\\\nbar\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let h1 = p.children.first as? HTMLNode
    else {
      Issue.record("Expected inline HTML")
      return
    }
    #expect(h1.content == "<a href=\"foo\\\nbar\">")
    #expect(sig(r.root) == "document[paragraph[html]]")
  }

  // 664 - Lone trailing backslash becomes literal backslash
  @Test("Spec 664: Lone trailing backslash is literal")
  func spec664() {
    let input = "foo\\\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected paragraph text")
      return
    }
    #expect(t.content == "foo\\")
    #expect(sig(r.root) == "document[paragraph[text(\"foo\\\\\")]]")
  }

  // 665 - Trailing two spaces at end of paragraph line do not create a break
  @Test("Spec 665: Trailing two spaces at end of paragraph")
  func spec665() {
    let input = "foo  \n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected paragraph text")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect(t.content == "foo")
    #expect(sig(r.root) == "document[paragraph[text(\"foo\")]]")
  }

  // 666 - Heading with trailing backslash
  @Test("Spec 666: Heading with trailing backslash")
  func spec666() {
    let input = "### foo\\\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let h3 = r.root.children.first as? HeaderNode else {
      Issue.record("Expected heading")
      return
    }
    #expect(h3.level == 3)
    let texts = findNodes(in: h3, ofType: TextNode.self)
    #expect(texts.count == 1)
    #expect(texts.first?.content == "foo\\")
    #expect(sig(r.root) == "document[heading(level:3)[text(\"foo\\\\\")]]")
  }

  // 667 - Heading with trailing two spaces
  @Test("Spec 667: Heading with trailing two spaces")
  func spec667() {
    let input = "### foo  \n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let h3 = r.root.children.first as? HeaderNode else {
      Issue.record("Expected heading")
      return
    }
    #expect(h3.level == 3)
    let texts = findNodes(in: h3, ofType: TextNode.self)
    #expect(texts.count == 1)
    #expect(texts.first?.content == "foo")
    #expect(sig(r.root) == "document[heading(level:3)[text(\"foo\")]]")
  }

  // 668 - Soft line break
  @Test("Spec 668: Soft line break")
  func spec668() {
    let input = "foo\nbaz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(soft),text(\"baz\")]]")
  }

  // 669 - Soft line break with trailing/leading spaces on lines
  @Test("Spec 669: Soft line break with surrounding spaces")
  func spec669() {
    let input = "foo \n baz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .lineBreak, .text])
    #expect(sig(r.root) == "document[paragraph[text(\"foo\"),line_break(soft),text(\"baz\")]]")
  }
}

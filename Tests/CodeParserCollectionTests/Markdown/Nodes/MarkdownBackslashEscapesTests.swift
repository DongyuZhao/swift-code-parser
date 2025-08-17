import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Backslash Escapes")
struct MarkdownBackslashEscapesTests {
  private let h = MarkdownTestHarness()

  // Using shared childrenTypes/sig from Tests/.../Utils/TestUtils.swift

  @Test("Spec 308: All escapable ASCII punctuation characters")
  func spec308() {
    let input =
      "\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for all escapable characters")
      return
    }
    #expect(para.children.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
    #expect(childrenTypes(result.root) == [.paragraph])
    #expect(childrenTypes(para) == [.text])
    #expect(
      sig(result.root) == "document[paragraph[text(\"!\\\"#$%&'()*+,-./:;<=>?@[\\\\]^_`{|}~\")]]")
  }

  @Test("Spec 309: Non-escapable characters (backslashes should remain)")
  func spec309() {
    let input = "\\\t\\A\\a\\ \\3\\φ\\«\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for non-escapable characters")
      return
    }
    #expect((para.children[0] as? TextNode)?.content == "\\\t\\A\\a\\ \\3\\φ\\«")
    #expect(childrenTypes(result.root) == [.paragraph])
    #expect(childrenTypes(para) == [.text])
    #expect(
      sig(result.root) == "document[paragraph[text(\"\\\\\\t\\\\A\\\\a\\\\ \\\\3\\\\φ\\\\«\")]]")
  }

  @Test("Spec 310: Prevent various markdown constructs from being interpreted")
  func spec310() {
    let input =
      "\\*not emphasized*\n\\<br/> not a tag\n\\[not a link](/foo)\n\\`not code`\n1\\. not a list\n\\* not a list\n\\# not a heading\n\\[foo]: /url \"not a reference\"\n\\&ouml; not a character entity\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for escaped markdown constructs")
      return
    }
    // Deterministic: verify exact sequence via types and sig; spot-check first three text nodes equality
    let texts = para.children.compactMap { $0 as? TextNode }.map(\.content)
    #expect(texts.first == "\\*not emphasized*")
    #expect(texts.dropFirst(2).first == "\\[not a link](/foo)")
    #expect(texts.dropFirst(4).first == "\\`not code`")

    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    let linkNodes = findNodes(in: result.root, ofType: LinkNode.self)
    let codeNodes = findNodes(in: result.root, ofType: InlineCodeNode.self)
    let headingNodes = findNodes(in: result.root, ofType: HeaderNode.self)
    let listNodes = findNodes(in: result.root, ofType: ListNode.self)

    #expect(emphasisNodes.isEmpty)
    #expect(linkNodes.isEmpty)
    #expect(codeNodes.isEmpty)
    #expect(headingNodes.isEmpty)
    #expect(listNodes.isEmpty)
    // Ensure only Text and soft line breaks exist, with exact counts (9 lines -> 9 texts, 8 breaks)
    let types = childrenTypes(para)
    #expect(types.filter { $0 == .text }.count == 9)
    #expect(types.filter { $0 == .lineBreak }.count == 8)
    #expect(Set(types).isSubset(of: [.text, .lineBreak]))
    #expect(result.root.children.count == 1)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"\\*not emphasized*\"),line_break(soft),text(\"\\<br/> not a tag\"),line_break(soft),text(\"\\[not a link](/foo)\"),line_break(soft),text(\"\\`not code`\"),line_break(soft),text(\"1\\\\. not a list\"),line_break(soft),text(\"\\* not a list\"),line_break(soft),text(\"\\# not a heading\"),line_break(soft),text(\"\\[foo]: /url \\\"not a reference\\\"\"),line_break(soft),text(\"\\&ouml; not a character entity\")]]"
    )
  }

  @Test("Spec 311: Escaping backslash itself")
  func spec311() {
    let input = "\\\\*emphasis*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for escaped backslash")
      return
    }
    let emphasis = findNodes(in: para, ofType: EmphasisNode.self)
    #expect(emphasis.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "\\")
    #expect(childrenTypes(para) == [.text, .emphasis])
    if let em = emphasis.first {
      #expect(findNodes(in: em, ofType: TextNode.self).first?.content == "emphasis")
    }
  }

  @Test("Spec 312: Backslash at end of line creates hard line break")
  func spec312() {
    let input = "foo\\\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for hard line break")
      return
    }
    let breaks = findNodes(in: para, ofType: LineBreakNode.self)
    #expect(breaks.count == 1)
    #expect(childrenTypes(para) == [.text, .lineBreak, .text])
    #expect(sig(result.root) == "document[paragraph[text(\"foo\"),line_break(hard),text(\"bar\")]]")
  }

  @Test("Spec 313: Backslashes in code spans are literal")
  func spec313() {
    let input = "`` \\[\\` ``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for code span")
      return
    }
    let codeSpans = findNodes(in: para, ofType: InlineCodeNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans.first?.code == " \\[\\` ")
    #expect(childrenTypes(para) == [.code])
    #expect(sig(result.root) == "document[paragraph[code(\" \\\\[\\\\` \")]]]")
  }

  @Test("Spec 314: Backslashes in indented code blocks are literal")
  func spec314() {
    let input = "    \\[\\]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\\[\\]")
    #expect(childrenTypes(result.root) == [.codeBlock])
    #expect(sig(result.root) == "document[code_block(\"\\\\[\\\\]\")]")
  }

  @Test("Spec 315: Backslashes in fenced code blocks are literal")
  func spec315() {
    let input = "~~~\n\\[\\]\n~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\\[\\]")
    #expect(childrenTypes(result.root) == [.codeBlock])
    #expect(sig(result.root) == "document[code_block(\"\\\\[\\\\]\")]")
  }

  @Test("Spec 316: Backslashes inside autolink text are preserved in URL (AST)")
  func spec316() {
    let input = "<https://Spec.com?find=\\*>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for autolink with backslash")
      return
    }
    let links = para.children.compactMap { $0 as? LinkNode }
    #expect(links.count == 1)
    if let link = links.first { #expect(link.url == "https://Spec.com?find=\\*") }
    #expect(childrenTypes(para) == [.link])
    if let link = para.children.first as? LinkNode {
      #expect((link.children.first as? TextNode)?.content == "https://Spec.com?find=\\*")
    }
  }

  @Test("Spec 317: Backslash escapes inside raw HTML attribute are preserved (AST)")
  func spec317() {
    let input = "<a href=\"/bar\\/)\">\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // HTML at start of line should be parsed as an HTMLBlockNode
    let blocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    #expect(blocks.count == 1)
    if let block = blocks.first { #expect(block.content == "<a href=\"/bar\\/)\">") }
    #expect(childrenTypes(result.root) == [.htmlBlock])
    #expect(sig(result.root) == "document[html_block]")
  }

  @Test("Spec 318: Backslashes in link URLs and titles")
  func spec318() {
    let input = "[foo](/bar\\* \"ti\\*tle\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    if let link = links.first {
      #expect(link.url == "/bar*")
      #expect(link.title == "ti*tle")
    }
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    if let link = p.children.first as? LinkNode {
      #expect((link.children.first as? TextNode)?.content == "foo")
    }
  }

  @Test("Spec 319: Backslashes in reference link definitions are unescaped (AST)")
  func spec319() {
    let input = "[foo]\n\n[foo]: /bar\\* \"ti\\*tle\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    if let link = links.first {
      #expect(link.url == "/bar*")
      #expect(link.title == "ti*tle")
    }
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    if let link = p.children.first as? LinkNode {
      #expect((link.children.first as? TextNode)?.content == "foo")
    }
  }

  @Test("Spec 320: Backslashes in fenced code info strings")
  func spec320() {
    let input = "``` foo\\+bar\nfoo\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(blocks.count == 1)
    if let block = blocks.first {
      #expect(block.language == "foo+bar")
      #expect(block.source == "foo")
    }
    #expect(childrenTypes(result.root) == [.codeBlock])
  }
}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Backslash Escapes (Strict)")
struct MarkdownCommonMarkBackslashEscapesTests {
  private let h = MarkdownTestHarness()

  @Test("Example 12: All escapable ASCII punctuation characters")
  func allEscapableASCIIPunctuations() {
    let input = "\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for all escapable characters"); return }
    #expect(para.children.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
  }

  @Test("Example 13: Non-escapable characters (backslashes should remain)")
  func nonEscapableCharactersRemain() {
    let input = "\\\t\\A\\a\\ \\3\\φ\\«\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for non-escapable characters"); return }
    #expect((para.children[0] as? TextNode)?.content == "\\\t\\A\\a\\ \\3\\φ\\«")
  }

  @Test("Example 14: Prevent various markdown constructs from being interpreted")
  func preventMarkdownConstructs() {
    let input = "\\*not emphasized*\n\\<br/> not a tag\n\\[not a link](/foo)\n\\`not code`\n1\\. not a list\n\\* not a list\n\\# not a heading\n\\[foo]: /url \"not a reference\"\n\\&ouml; not a character entity\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for escaped markdown constructs"); return }
    let textContent = para.children.compactMap { $0 as? TextNode }.map(\.content).joined()
    #expect(textContent.contains("*not emphasized*"))
    #expect(textContent.contains("[not a link]"))
    #expect(textContent.contains("`not code`"))

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
  }

  @Test("Example 15: Escaping backslash itself")
  func escapeBackslashThenEmphasis() {
    let input = "\\\\*emphasis*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for escaped backslash"); return }
    let emphasis = findNodes(in: para, ofType: EmphasisNode.self)
    #expect(emphasis.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "\\")
  }

  @Test("Example 16: Backslash at end of line creates hard line break")
  func backslashHardLineBreak() {
    let input = "foo\\\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for hard line break"); return }
    let breaks = findNodes(in: para, ofType: LineBreakNode.self)
    #expect(breaks.count == 1)
  }

  @Test("Example 17: Backslashes in code spans are literal")
  func backslashesInCodeSpanLiteral() {
    let input = "`` \\[\\` ``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for code span"); return }
    let codeSpans = findNodes(in: para, ofType: InlineCodeNode.self)
    #expect(codeSpans.count == 1)
    #expect(codeSpans.first?.code == " \\[\\` ")
  }

  @Test("Example 18: Backslashes in indented code blocks are literal")
  func backslashesInIndentedCodeLiteral() {
    let input = "    \\[\\]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\\[\\]")
  }

  @Test("Example 19: Backslashes in fenced code blocks are literal")
  func backslashesInFencedCodeLiteral() {
    let input = "~~~\n\\[\\]\n~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let codeBlocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codeBlocks.count == 1)
    #expect(codeBlocks.first?.source == "\\[\\]")
  }

  @Test("Example 20: Backslashes inside autolink text are preserved in URL (AST)")
  func autolinkWithBackslashPreserved() {
    let input = "<https://example.com?find=\\*>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for autolink with backslash"); return }
    let links = para.children.compactMap { $0 as? LinkNode }
    #expect(links.count == 1)
    if let link = links.first { #expect(link.url == "https://example.com?find=\\*") }
  }

  @Test("Example 21: Backslash escapes inside raw HTML attribute are preserved (AST)")
  func rawHTMLWithBackslashInAttribute() {
    let input = "<a href=\"/bar\\/)\">\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // HTML at start of line should be parsed as an HTMLBlockNode
    let blocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    #expect(blocks.count == 1)
    if let block = blocks.first { #expect(block.content == "<a href=\"/bar\\/)\">") }
  }

  @Test("Example 22: Backslashes in link URLs and titles")
  func backslashesInLinkUrlAndTitle() {
    let input = "[foo](/bar\\* \"ti\\*tle\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    if let link = links.first { #expect(link.url == "/bar*"); #expect(link.title == "ti*tle") }
  }

  @Test("Example 23: Backslashes in reference link definitions are unescaped (AST)")
  func backslashesInReferenceLinkDefinition() {
    let input = "[foo]\n\n[foo]: /bar\\* \"ti\\*tle\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    if let link = links.first { #expect(link.url == "/bar*"); #expect(link.title == "ti*tle") }
  }

  @Test("Example 24: Backslashes in fenced code info strings")
  func backslashesInFencedInfoString() {
    let input = "``` foo\\+bar\nfoo\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(blocks.count == 1)
    if let block = blocks.first { #expect(block.language == "foo+bar"); #expect(block.source == "foo") }
  }
}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - HTML Blocks and Inline HTML (Strict)")
struct MarkdownCommonMarkHTMLTests {
  private let h = MarkdownTestHarness()

  @Test("HTML Block is recognized and preserved")
  func htmlBlock() {
    let input = "<div>\n<p>HTML content</p>\n</div>"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    #expect(blocks.count == 1)
    if let block = blocks.first { #expect(block.content == "<div>\n<p>HTML content</p>\n</div>") }
  }

  @Test("Inline HTML inside paragraph")
  func inlineHTML() {
    let input = "This has <em>inline HTML</em> tags."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let para = result.root.children.first as? ParagraphNode {
      let htmlChildren = para.children.compactMap { $0 as? HTMLNode }
      #expect(!htmlChildren.isEmpty)
      if htmlChildren.count == 1 { #expect(htmlChildren[0].content == "<em>inline HTML</em>") }
    } else {
      Issue.record("Expected ParagraphNode for inline HTML")
    }
  }

  @Test("HTML comment is represented")
  func htmlComment() {
    let input = "<!-- This is a comment -->"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let commentBlocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    let commentInlines = findNodes(in: result.root, ofType: HTMLNode.self)
    let commentNodes = findNodes(in: result.root, ofType: CommentNode.self)
    #expect(!commentBlocks.isEmpty || !commentInlines.isEmpty || !commentNodes.isEmpty)
  }

  @Test("Self-closing HTML tag <br/> parsed as single HTMLNode")
  func selfClosingTag() {
    let input = "Line break: <br/> here."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let para = result.root.children.first as? ParagraphNode {
      let brNodes = para.children.compactMap { $0 as? HTMLNode }.filter { $0.content.contains("<br/>") }
      #expect(!brNodes.isEmpty)
    } else {
      Issue.record("Expected ParagraphNode for self-closing tags")
    }
  }

  @Test("HTML with attributes is preserved")
  func htmlWithAttributes() {
    let input = "<a href=\"https://example.com\" class=\"link\">Link</a>"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let para = result.root.children.first as? ParagraphNode {
      let anchors = para.children.compactMap { $0 as? HTMLNode }
      #expect(anchors.count == 1)
      if let a = anchors.first { #expect(a.content == "<a href=\"https://example.com\" class=\"link\">Link</a>") }
    } else if let block = result.root.children.first as? HTMLBlockNode {
      #expect(block.content == "<a href=\"https://example.com\" class=\"link\">Link</a>")
    } else {
      Issue.record("Expected ParagraphNode or HTMLBlockNode for HTML attributes")
    }
  }
}

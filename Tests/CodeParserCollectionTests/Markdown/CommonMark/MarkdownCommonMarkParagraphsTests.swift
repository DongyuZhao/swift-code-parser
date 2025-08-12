import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Paragraphs (Strict)")
struct MarkdownCommonMarkParagraphsTests {
  private let h = MarkdownTestHarness()

  @Test("Single paragraph")
  func singleParagraph() {
    let input = "This is a paragraph."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    #expect(para.children.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "This is a paragraph.")
  }

  @Test("Multiple paragraphs separated by blank line")
  func multipleParagraphs() {
    let input = "Paragraph 1.\n\nParagraph 2."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
          let p2 = result.root.children[1] as? ParagraphNode else { Issue.record("Expected two ParagraphNodes"); return }
    #expect((p1.children[0] as? TextNode)?.content == "Paragraph 1.")
    #expect((p2.children[0] as? TextNode)?.content == "Paragraph 2.")
  }

  @Test("Paragraph with soft line break")
  func paragraphSoftBreak() {
    let input = "Line 1\nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for soft break"); return }
    let textNodes = para.children.compactMap { $0 as? TextNode }
    let allText = textNodes.map { $0.content }.joined()
    #expect(allText.contains("Line 1"))
    #expect(allText.contains("Line 2"))
  }
}

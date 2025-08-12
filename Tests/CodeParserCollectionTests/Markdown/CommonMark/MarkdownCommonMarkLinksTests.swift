import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Links (Strict)")
struct MarkdownCommonMarkLinksTests {
  private let h = MarkdownTestHarness()

  @Test("Inline link with exact structure")
  func inlineLink() {
    let input = "Visit [GitHub](https://github.com) for code."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "Visit ")
    guard let link = para.children[1] as? LinkNode else { Issue.record("Expected LinkNode at position 1"); return }
    #expect(link.url == "https://github.com")
    #expect(link.children.count == 1)
    #expect((link.children[0] as? TextNode)?.content == "GitHub")
    #expect((para.children[2] as? TextNode)?.content == " for code.")
  }

  @Test("Reference link resolves")
  func referenceLink() {
    let input = "Visit [GitHub][gh] for code.\n\n[gh]: https://github.com \"GitHub\""
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    if let link = links.first {
      #expect(link.url == "https://github.com")
      #expect(link.title == "GitHub")
    }
  }

  @Test("Autolink detected")
  func autolink() {
    let input = "Visit <https://github.com> now."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for autolink"); return }
    let autoLinks = para.children.compactMap { $0 as? LinkNode }
    #expect(autoLinks.count == 1)
    if let autoLink = autoLinks.first { #expect(autoLink.url == "https://github.com") }
  }
}

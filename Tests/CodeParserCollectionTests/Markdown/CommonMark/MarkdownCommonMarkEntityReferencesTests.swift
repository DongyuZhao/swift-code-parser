import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Entity References (Strict)")
struct MarkdownCommonMarkEntityReferencesTests {
  private let h = MarkdownTestHarness()

  @Test("Named entities parse into HTML nodes")
  func namedEntities() {
    let input = "AT&amp;T uses &lt;brackets&gt;"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    let htmlNodes = para.children.compactMap { $0 as? HTMLNode }
    #expect(htmlNodes.count >= 3)
  }

  @Test("Numeric entities parse into HTML nodes")
  func numericEntities() {
    let input = "A is &#65; and &#x41;"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for numeric entities"); return }
    let nodes = para.children.compactMap { $0 as? HTMLNode }
    #expect(nodes.count >= 2)
  }
}

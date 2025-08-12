import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Setext Headings (Strict)")
struct MarkdownCommonMarkSetextHeadingsTests {
  private let h = MarkdownTestHarness()

  @Test("Level 1 setext heading")
  func setextLevel1() {
    let input = "Heading Level 1\n==============="
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let heading = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode for setext level 1")
      return
    }
    #expect(heading.level == 1)
    guard let text = heading.children.first as? TextNode else {
      Issue.record("Expected TextNode in setext heading")
      return
    }
    #expect(text.content == "Heading Level 1")
  }

  @Test("Level 2 setext heading")
  func setextLevel2() {
    let input = "Heading Level 2\n---------------"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let heading = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode for setext level 2")
      return
    }
    #expect(heading.level == 2)
    guard let text = heading.children.first as? TextNode else {
      Issue.record("Expected TextNode in setext heading")
      return
    }
    #expect(text.content == "Heading Level 2")
  }
}

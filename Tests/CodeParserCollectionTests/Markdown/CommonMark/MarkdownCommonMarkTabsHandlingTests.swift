import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Tabs handling (Strict)")
struct MarkdownCommonMarkTabsHandlingTests {
  private let h = MarkdownTestHarness()

  @Test("Example 1: Tab at start becomes code block with exact content")
  func tabAtStartBecomesCodeBlock() {
    let input = "\tfoo\tbaz\t\tbim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let codeBlock = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode as first child")
      return
    }
    #expect(codeBlock.source == "foo\tbaz\t\tbim")
    #expect(codeBlock.language == nil || codeBlock.language?.isEmpty == true)
  }

  @Test("Example 2: Spaces + tab becomes code block")
  func spacesPlusTabBecomesCodeBlock() {
    let input = "  \tfoo\tbaz\t\tbim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let codeBlock = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode as first child")
      return
    }
    #expect(codeBlock.source == "foo\tbaz\t\tbim")
  }
}

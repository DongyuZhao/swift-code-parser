import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Indented Code Blocks (Strict)")
struct MarkdownCommonMarkIndentedCodeBlocksTests {
  private let h = MarkdownTestHarness()

  @Test("Indented code block strips 4 spaces and preserves empty lines")
  func indentedCodeBlock() {
    let input = "    code line 1\n    code line 2\n    \n    code line 4"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let codeBlock = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    let expected = "code line 1\ncode line 2\n\ncode line 4"
    #expect(codeBlock.source == expected)
    #expect(codeBlock.language == nil || codeBlock.language?.isEmpty == true)
  }
}

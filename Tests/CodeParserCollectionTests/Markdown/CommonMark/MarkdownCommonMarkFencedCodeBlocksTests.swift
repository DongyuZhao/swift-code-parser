import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Fenced Code Blocks (Strict)")
struct MarkdownCommonMarkFencedCodeBlocksTests {
  private let h = MarkdownTestHarness()

  @Test("Backticks fenced code block")
  func backticksFence() {
    let input = "```\ncode line 1\ncode line 2\n```"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let code = result.root.children.first as? CodeBlockNode else { Issue.record("Expected CodeBlockNode"); return }
    #expect(code.source == "code line 1\ncode line 2")
    #expect(code.language == nil || code.language?.isEmpty == true)
  }

  @Test("Fenced code block with language")
  func fencedWithLanguage() {
    let input = "```swift\nlet x = 1\nlet y = 2\n```"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let code = result.root.children.first as? CodeBlockNode else { Issue.record("Expected CodeBlockNode with language"); return }
    #expect(code.language == "swift")
    #expect(code.source == "let x = 1\nlet y = 2")
  }

  @Test("Tilde fenced code block with language")
  func tildeFence() {
    let input = "~~~python\nprint('hello world')\nprint('second line')\n~~~"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else { Issue.record("Expected CodeBlockNode with tilde fences"); return }
    #expect(code.language == "python")
    #expect(code.source == "print('hello world')\nprint('second line')")
  }

  @Test("Fenced code block with info string")
  func fencedWithInfoString() {
    let input = "```javascript {.line-numbers}\nconsole.log('test');\n```"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else { Issue.record("Expected CodeBlockNode with info string"); return }
    #expect(code.language == "javascript")
  }

  @Test("Too few backticks should not create code block")
  func tooFewBackticks() {
    let input = "``\ncode\n``"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let hasCode = result.root.children.contains { $0 is CodeBlockNode }
    #expect(!hasCode)
  }
}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Code Spans (Strict)")
struct MarkdownCommonMarkCodeSpansTests {
  private let h = MarkdownTestHarness()

  @Test("Simple code span")
  func simpleCodeSpan() {
    let input = "Use `code` in text."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "Use ")
    guard let code = para.children[1] as? InlineCodeNode else { Issue.record("Expected InlineCodeNode at position 1"); return }
    #expect(code.code == "code")
    #expect((para.children[2] as? TextNode)?.content == " in text.")
  }

  @Test("Code span with backticks inside")
  func codeSpanWithInnerBackticks() {
    let input = "Use `` code with `backtick` `` here."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for complex code"); return }
    let codes = para.children.compactMap { $0 as? InlineCodeNode }
    #expect(codes.count == 1)
    if let code = codes.first { #expect(code.code == " code with `backtick` ") }
  }
}

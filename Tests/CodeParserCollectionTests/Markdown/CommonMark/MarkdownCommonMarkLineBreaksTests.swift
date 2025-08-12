import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Line Breaks (Strict)")
struct MarkdownCommonMarkLineBreaksTests {
  private let h = MarkdownTestHarness()

  @Test("Hard line break with backslash")
  func hardBreakBackslash() {
    let input = "Line 1\\\nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    let breaks = para.children.compactMap { $0 as? LineBreakNode }
    #expect(breaks.count == 1)
    if let br = breaks.first { #expect(br.variant == .hard) }
  }

  @Test("Hard line break with two trailing spaces")
  func hardBreakTwoSpaces() {
    let input = "Line 1  \nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for trailing spaces"); return }
    let breaks = para.children.compactMap { $0 as? LineBreakNode }
    #expect(breaks.count == 1)
    if let br = breaks.first { #expect(br.variant == .hard) }
  }

  @Test("Hard line break with more trailing spaces")
  func hardBreakThreeSpaces() {
    let input = "Line 1   \nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for multiple spaces"); return }
    let breaks = para.children.compactMap { $0 as? LineBreakNode }
    #expect(breaks.count == 1)
    if let br = breaks.first { #expect(br.variant == .hard) }
  }

  @Test("Soft line break remains soft")
  func softBreak() {
    let input = "Line 1\nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for soft break"); return }
    let textNodes = para.children.compactMap { $0 as? TextNode }
    let allText = textNodes.map { $0.content }.joined()
    #expect(allText.contains("Line 1"))
    #expect(allText.contains("Line 2"))
  }

  @Test("Single trailing space should NOT be hard break")
  func singleTrailingSpaceNotHardBreak() {
    let input = "Line 1 \nLine 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for single space"); return }
    let hardBreaks = para.children.compactMap { $0 as? LineBreakNode }.filter { $0.variant == .hard }
    #expect(hardBreaks.isEmpty)
  }
}

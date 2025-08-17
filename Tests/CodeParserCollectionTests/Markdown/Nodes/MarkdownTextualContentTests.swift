import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Textual Content")
struct MarkdownTextualContentTests {
  private let h = MarkdownTestHarness()

  // Using shared childrenTypes/sig from Tests/.../Utils/TestUtils.swift

  // 670
  @Test("Spec 670: Punctuation and symbols are literal text")
  func spec670() {
    let input = "hello $.;'there\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected ParagraphNode with TextNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect(t.content == "hello $.;'there")
    #expect(sig(r.root) == "document[paragraph[text(\"hello $.;'there\")]]")
  }

  // 671
  @Test("Spec 671: Unicode letters preserved in text")
  func spec671() {
    let input = "Foo \\u03c7\\u03c1\\u1fc6\\u03bd\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected ParagraphNode with TextNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect(t.content == "Foo \u{03c7}\u{03c1}\u{1fc6}\u{03bd}")
    #expect(sig(r.root) == "document[paragraph[text(\"Foo \u{03c7}\u{03c1}\u{1fc6}\u{03bd}\")]]")
  }

  // 672
  @Test("Spec 672: Multiple spaces are preserved as literal text")
  func spec672() {
    let input = "Multiple     spaces\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected ParagraphNode with TextNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect(t.content == "Multiple     spaces")
    #expect(sig(r.root) == "document[paragraph[text(\"Multiple     spaces\")]]")
  }
}

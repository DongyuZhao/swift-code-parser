import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("GFM - Strikethrough Extension")
struct MarkdownStrikesTests {
  private let h = MarkdownTestHarness()

  // Example 491: Basic strikethrough with tildes (GFM Extension)
  @Test("Example 491: ~~Hi~~ Hello, world! - strikethrough text")
  func spec491() {
    let input = "~~Hi~~ Hello, world!\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 1)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Expect inline sequence: strike("Hi"), text(" Hello, world!")
    #expect(p.children.count == 2)
    guard let s = p.children.first as? StrikeNode, let t = p.children.last as? TextNode else {
      Issue.record("Expected [StrikeNode, TextNode]")
      return
    }
    let inner = findNodes(in: s, ofType: TextNode.self).map { $0.content }.joined()
    #expect(inner == "Hi")
    #expect(t.content == " Hello, world!")
    #expect(sig(r.root) == "document[paragraph[strike[text(\"Hi\")],text(\" Hello, world!\")]]")
  }

  // Example 492: Strikethrough cannot span paragraphs (GFM Extension)
  @Test("Example 492: ~~text across\n\nparagraphs~~ - no strikethrough across paragraphs")
  func spec492() {
    let input = "This ~~has a\n\nnew paragraph~~.\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    guard let p1 = r.root.children.first as? ParagraphNode,
      let p2 = r.root.children.last as? ParagraphNode
    else {
      Issue.record("Expected two ParagraphNode blocks")
      return
    }
    // No StrikeNode should be present; literal tildes remain
    #expect(findNodes(in: p1, ofType: StrikeNode.self).isEmpty)
    #expect(findNodes(in: p2, ofType: StrikeNode.self).isEmpty)
    let t1 = findNodes(in: p1, ofType: TextNode.self).map { $0.content }.joined()
    let t2 = findNodes(in: p2, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t1 == "This ~~has a")
    #expect(t2 == "new paragraph~~.")
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"This ~~has a\")],paragraph[text(\"new paragraph~~.\")]]"
    )
  }
}

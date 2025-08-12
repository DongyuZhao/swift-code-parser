import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Emphasis and Strong (Strict)")
struct MarkdownCommonMarkEmphasisStrongTests {
  private let h = MarkdownTestHarness()

  // MARK: - Helpers (ported from MarkdownEmphasisSpecTests)
  private func parseParagraph(_ md: String) -> ParagraphNode? {
    let result = h.parser.parse(md, language: h.language)
    #expect(result.errors.isEmpty)
    return result.root.children.first { $0.element == .paragraph } as? ParagraphNode
  }

  @Test("Simple emphasis with asterisks")
  func simpleEmphasisAsterisks() {
    let input = "This is *emphasized* text."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "This is ")
    guard let emphasis = para.children[1] as? EmphasisNode else { Issue.record("Expected EmphasisNode at position 1"); return }
    #expect(emphasis.children.count == 1)
    #expect((emphasis.children[0] as? TextNode)?.content == "emphasized")
    #expect((para.children[2] as? TextNode)?.content == " text.")
  }

  @Test("Strong emphasis with asterisks")
  func strongEmphasisAsterisks() {
    let input = "This is **strong** text."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for strong"); return }
    #expect(para.children.count == 3)
    guard let strong = para.children[1] as? StrongNode else { Issue.record("Expected StrongNode at position 1"); return }
    #expect(strong.children.count == 1)
    #expect((strong.children[0] as? TextNode)?.content == "strong")
  }

  @Test("Intraword underscores should NOT create emphasis")
  func intrawordUnderscoresNoEmphasis() {
    let input = "foo_bar_baz"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode for intraword"); return }
    #expect(para.children.count == 1)
    #expect((para.children[0] as? TextNode)?.content == "foo_bar_baz")
  }

  @Test("Triple asterisks (***both strong and emphasized***)")
  func tripleAsterisksCombined() {
    let input = "This is ***both strong and emphasized*** text."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard result.root.children.first is ParagraphNode else { Issue.record("Expected ParagraphNode for triple asterisks"); return }
    let strongNodes = findNodes(in: result.root, ofType: StrongNode.self)
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(strongNodes.count >= 1)
    #expect(emphasisNodes.count >= 1)
  }

  @Test("Triple underscores (___both strong and emphasized___)")
  func tripleUnderscoresCombined() {
    let input = "This is ___both strong and emphasized___ text."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard result.root.children.first is ParagraphNode else { Issue.record("Expected ParagraphNode for triple underscores"); return }
    let strongNodes = findNodes(in: result.root, ofType: StrongNode.self)
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(strongNodes.count >= 1)
    #expect(emphasisNodes.count >= 1)
  }

  @Test("Nested emphasis within strong")
  func nestedEmphasisWithinStrong() {
    let input = "**This is *nested* emphasis**"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let strongNodes = findNodes(in: result.root, ofType: StrongNode.self)
    let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
    #expect(strongNodes.count == 1)
    #expect(emphasisNodes.count == 1)
  }

  // MARK: - Ported cases from MarkdownEmphasisSpecTests.swift

  @Test("asterisk emphasis")
  func asteriskEmphasis() {
    let md = "This is *italic* text."
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 3)
    #expect((para!.children[0] as? TextNode)?.content == "This is ")
    guard let em = para!.children[1] as? EmphasisNode else {
      let ok = false; #expect(ok, "Second child should be Emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "italic")
    #expect((para!.children[2] as? TextNode)?.content == " text.")
  }

  @Test("underscore emphasis")
  func underscoreEmphasis() {
    let md = "This is _italic_ text."
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 3)
    #expect((para!.children[0] as? TextNode)?.content == "This is ")
    guard let em = para!.children[1] as? EmphasisNode else {
      let ok = false; #expect(ok, "Second child should be Emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "italic")
    #expect((para!.children[2] as? TextNode)?.content == " text.")
  }

  @Test("asterisk strong")
  func asteriskStrong_ported() {
    let md = "This is **bold** text."
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 3)
    #expect((para!.children[0] as? TextNode)?.content == "This is ")
    guard let strong = para!.children[1] as? StrongNode else {
      let ok = false; #expect(ok, "Second child should be Strong")
      return
    }
    #expect(strong.children.count == 1)
    #expect((strong.children.first as? TextNode)?.content == "bold")
    #expect((para!.children[2] as? TextNode)?.content == " text.")
  }

  @Test("underscore strong")
  func underscoreStrong() {
    let md = "This is __bold__ text."
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 3)
    #expect((para!.children[0] as? TextNode)?.content == "This is ")
    guard let strong = para!.children[1] as? StrongNode else {
      let ok = false; #expect(ok, "Second child should be Strong")
      return
    }
    #expect(strong.children.count == 1)
    #expect((strong.children.first as? TextNode)?.content == "bold")
    #expect((para!.children[2] as? TextNode)?.content == " text.")
  }

  @Test("triple asterisks nest strong+em")
  func tripleAsterisksNest() {
    let md = "***both***"
    let para = parseParagraph(md)
    #expect(para != nil)
    // Per CommonMark, ***foo*** yields nested strong outside, emphasis inside
    #expect(para!.children.count == 1)
    guard let strong = para!.children.first as? StrongNode else {
      let ok = false
      #expect(ok, "Outer should be strong")
      return
    }
    #expect(strong.children.count == 1)
    guard let em = strong.children.first as? EmphasisNode else {
      let ok = false
      #expect(ok, "Inner should be emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "both")
  }

  @Test("triple underscores nest strong+em")
  func tripleUnderscoresNest() {
    let md = "___both___"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 1)
    guard let strong = para!.children.first as? StrongNode else {
      let ok = false
      #expect(ok, "Outer should be strong")
      return
    }
    #expect(strong.children.count == 1)
    guard let em = strong.children.first as? EmphasisNode else {
      let ok = false
      #expect(ok, "Inner should be emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "both")
  }

  @Test("strong with inner emphasis")
  func strongWithInnerEmphasis() {
    let md = "**bold and *italic* inside**"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 1)
    guard let strong = para!.children.first as? StrongNode else {
      let ok = false; #expect(ok, "Outer should be Strong")
      return
    }
    #expect(strong.children.count == 3)
    #expect((strong.children[0] as? TextNode)?.content == "bold and ")
    guard let em = strong.children[1] as? EmphasisNode else {
      let ok = false; #expect(ok, "Middle should be Emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "italic")
    #expect((strong.children[2] as? TextNode)?.content == " inside")
  }

  @Test("emphasis contains strong with exact ordering")
  func emphasisContainsStrongOrdering() {
    let md = "*foo **bar** baz*"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 1)
    guard let em = para!.children.first as? EmphasisNode else {
      let ok = false
      #expect(ok, "Outer should be emphasis")
      return
    }
    #expect(em.children.count == 3)
    #expect((em.children[0] as? TextNode)?.content == "foo ")
    guard let strong = em.children[1] as? StrongNode else {
      let ok = false
      #expect(ok, "Middle should be strong")
      return
    }
    #expect(strong.children.count == 1)
    #expect((strong.children.first as? TextNode)?.content == "bar")
    #expect((em.children[2] as? TextNode)?.content == " baz")
  }

  @Test("strong contains emphasis with exact ordering")
  func strongContainsEmphasisOrdering() {
    let md = "**foo *bar* baz**"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 1)
    guard let strong = para!.children.first as? StrongNode else {
      let ok = false
      #expect(ok, "Outer should be strong")
      return
    }
    #expect(strong.children.count == 3)
    #expect((strong.children[0] as? TextNode)?.content == "foo ")
    guard let em = strong.children[1] as? EmphasisNode else {
      let ok = false
      #expect(ok, "Middle should be emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "bar")
    #expect((strong.children[2] as? TextNode)?.content == " baz")
  }

  @Test("underscores do not emphasize intraword")
  func intrawordUnderscoreNoEmphasis() {
    let md = "foo_bar_baz"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.first(where: { $0.element == .emphasis }) == nil)
  }

  @Test("underscores emphasize across intraword sequence when bounded")
  func underscoreAcrossWord() {
    let md = "_foo_bar_"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 1)
    guard let em = para!.children.first as? EmphasisNode else {
      let ok = false; #expect(ok, "Should be Emphasis only")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "foo_bar")
  }

  @Test("asterisks can emphasize intraword segment")
  func intrawordAsteriskYes() {
    let md = "foo*bar*baz"
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.children.count == 3)
    #expect((para!.children[0] as? TextNode)?.content == "foo")
    guard let em = para!.children[1] as? EmphasisNode else {
      let ok = false; #expect(ok, "Second child should be Emphasis")
      return
    }
    #expect(em.children.count == 1)
    #expect((em.children.first as? TextNode)?.content == "bar")
    #expect((para!.children[2] as? TextNode)?.content == "baz")
  }

  @Test("unmatched asterisk is literal")
  func unmatchedAsteriskLiteral() {
  let md = "* not closed"
  let result = h.parser.parse(md, language: h.language)
  #expect(result.errors.isEmpty)
  let emphasisNodes = findNodes(in: result.root, ofType: EmphasisNode.self)
  let strongNodes = findNodes(in: result.root, ofType: StrongNode.self)
  #expect(emphasisNodes.isEmpty)
  #expect(strongNodes.isEmpty)
  }

  @Test("escaped markers are literal")
  func escapedMarkersLiteral() {
    let md = #"\*not italic\* and \__not bold__"#
    let para = parseParagraph(md)
    #expect(para != nil)
    #expect(para!.first(where: { $0.element == .emphasis }) == nil)
    #expect(para!.first(where: { $0.element == .strong }) == nil)
  }
}

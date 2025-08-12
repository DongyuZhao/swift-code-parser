import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - ATX Headings (Strict)")
struct MarkdownCommonMarkATXHeadingsTests {
  private let h = MarkdownTestHarness()

  // CommonMark Spec - ATX headings

  @Test("Spec 62: ATX heading levels 1..6")
  func spec62_levels1To6() {
    let input = """
    # foo
    ## foo
    ### foo
    #### foo
    ##### foo
    ###### foo
    """
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 6)
    for (idx, node) in result.root.children.enumerated() {
      guard let hnode = node as? HeaderNode else { Issue.record("Expected HeaderNode at \(idx)"); return }
      #expect(hnode.level == idx + 1)
      let text = hnode.children.compactMap { ($0 as? TextNode)?.content }.joined()
      #expect(text == "foo")
    }
  }

  @Test("Spec 63: 7 leading # is not a heading")
  func spec63_moreThan6Hashes() {
    let input = "####### foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    let text = para.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "####### foo")
  }

  @Test("Spec 64: No space after # -> not a heading")
  func spec64_noSpaceAfterHash() {
    let input = "#5 bolt\n\n#hashtag\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children.first as? ParagraphNode,
          let p2 = result.root.children.dropFirst().first as? ParagraphNode
    else { Issue.record("Expected two ParagraphNode"); return }
    let t1 = p1.children.compactMap { ($0 as? TextNode)?.content }.joined()
    let t2 = p2.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(t1 == "#5 bolt")
    #expect(t2 == "#hashtag")
  }

  @Test("Spec 65: Escaped hashes -> not a heading")
  func spec65_escapedHashes() {
    let input = "\\## foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    let text = para.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "## foo")
  }

  @Test("Spec 66: Inline content in heading with escaped asterisks")
  func spec66_inlineInHeading() {
    let input = "# foo *bar* \\*baz\\*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let heading = result.root.children.first as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
    #expect(heading.level == 1)
    #expect(heading.children.count >= 3)
    // Expect: Text("foo "), Emphasis("bar"), Text(" *baz*")
    guard let t0 = heading.children.first as? TextNode else { Issue.record("Expected leading TextNode"); return }
    #expect(t0.content == "foo ")
    guard let em = heading.children.dropFirst().first(where: { $0 is EmphasisNode }) as? EmphasisNode else { Issue.record("Expected EmphasisNode"); return }
    #expect((em.children.first as? TextNode)?.content == "bar")
    guard let lastText = heading.children.last as? TextNode else { Issue.record("Expected trailing TextNode"); return }
    #expect(lastText.content == " *baz*")
  }

  @Test("Spec 67: Heading trims trailing spaces")
  func spec67_trimTrailingSpaces() {
    let input = "#                  foo                     \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let heading = result.root.children.first as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
    #expect(heading.level == 1)
    let text = heading.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "foo")
  }

  @Test("Spec 68: Up to 3 leading spaces are allowed before ATX")
  func spec68_leadingSpacesAllowed() {
    let input = " ### foo\n  ## foo\n   # foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    let levels = [3, 2, 1]
    for (i, child) in result.root.children.enumerated() {
      guard let hnode = child as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
      #expect(hnode.level == levels[i])
      let text = hnode.children.compactMap { ($0 as? TextNode)?.content }.joined()
      #expect(text == "foo")
    }
  }

  @Test("Spec 69: Four leading spaces -> indented code block, not heading")
  func spec69_indentedCodeBlock() {
    let input = "    # foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(blocks.count == 1)
    #expect(blocks.first?.source == "# foo")
  }

  @Test("Spec 70: Indented line inside paragraph is not a code block")
  func spec70_indentedInParagraph() {
    let input = "foo\n    # bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    // Should not contain HeaderNode or CodeBlockNode
    #expect(findNodes(in: para, ofType: HeaderNode.self).isEmpty)
    #expect(findNodes(in: para, ofType: CodeBlockNode.self).isEmpty)
    let text = para.children.compactMap { ($0 as? TextNode)?.content }.joined()
    // Normalize to ensure '# bar' exists (ignoring leading 4 spaces)
    #expect(text.contains("foo"))
    #expect(text.contains("# bar"))
  }

  @Test("Spec 71: Optional closing sequence with spaces")
  func spec71_closingSequence() {
    let input = "## foo ##\n  ###   bar    ###\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let h2 = result.root.children.first as? HeaderNode,
          let h3 = result.root.children.dropFirst().first as? HeaderNode
    else { Issue.record("Expected two HeaderNode"); return }
    #expect(h2.level == 2)
    #expect(h3.level == 3)
    #expect(h2.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo")
    #expect(h3.children.compactMap { ($0 as? TextNode)?.content }.joined() == "bar")
  }

  @Test("Spec 72: Long closing sequence is allowed")
  func spec72_longClosingSequence() {
    let input = "# foo ##################################\n##### foo ##\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let h1 = result.root.children.first as? HeaderNode,
          let h5 = result.root.children.dropFirst().first as? HeaderNode
    else { Issue.record("Expected two HeaderNode"); return }
    #expect(h1.level == 1)
    #expect(h5.level == 5)
    #expect(h1.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo")
    #expect(h5.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo")
  }

  @Test("Spec 73: Closing sequence may be followed by spaces")
  func spec73_closingFollowedBySpaces() {
    let input = "### foo ###     \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h3 = result.root.children.first as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
    #expect(h3.level == 3)
    #expect(h3.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo")
  }

  @Test("Spec 74: If non-space after closing sequence, treat hashes as text")
  func spec74_closingFollowedByNonSpace() {
    let input = "### foo ### b\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h3 = result.root.children.first as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
    #expect(h3.level == 3)
    // Text should include '### b'
    let text = h3.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "foo ### b")
  }

  @Test("Spec 75: Trailing # without preceding space is text, not closing seq")
  func spec75_trailingHashWithoutSpace() {
    let input = "# foo#\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let h1 = result.root.children.first as? HeaderNode else { Issue.record("Expected HeaderNode"); return }
    #expect(h1.level == 1)
    let text = h1.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text == "foo#")
  }

  @Test("Spec 76: Escaped closing sequence keeps hashes as text")
  func spec76_escapedClosingSequence() {
    let input = "### foo \\###\n## foo #\\##\n# foo \\#\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let h3 = result.root.children[0] as? HeaderNode,
          let h2 = result.root.children[1] as? HeaderNode,
          let h1 = result.root.children[2] as? HeaderNode
    else { Issue.record("Expected HeaderNodes"); return }
    #expect(h3.level == 3)
    #expect(h2.level == 2)
    #expect(h1.level == 1)
    #expect(h3.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo ###")
    #expect(h2.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo ###")
    #expect(h1.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo #")
  }

  @Test("Spec 77: Thematic break around ATX")
  func spec77_hrAndHeading() {
    let input = "****\n## foo\n****\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ThematicBreakNode)
    guard let h2 = result.root.children[1] as? HeaderNode else { Issue.record("Expected HeaderNode in middle"); return }
    #expect(h2.level == 2)
    #expect(h2.children.compactMap { ($0 as? TextNode)?.content }.joined() == "foo")
    #expect(result.root.children[2] is ThematicBreakNode)
  }

  @Test("Spec 78: Paragraphs around ATX")
  func spec78_paragraphsAroundHeading() {
    let input = "Foo bar\n# baz\nBar foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let p1 = result.root.children[0] as? ParagraphNode,
          let h1 = result.root.children[1] as? HeaderNode,
          let p2 = result.root.children[2] as? ParagraphNode
    else { Issue.record("Expected P, H1, P sequence"); return }
    #expect(h1.level == 1)
    #expect(p1.children.compactMap { ($0 as? TextNode)?.content }.joined() == "Foo bar")
    #expect(h1.children.compactMap { ($0 as? TextNode)?.content }.joined() == "baz")
    #expect(p2.children.compactMap { ($0 as? TextNode)?.content }.joined() == "Bar foo")
  }

  @Test("Spec 79: Empty headings")
  func spec79_emptyHeadings() {
    let input = "## \n#\n### ###\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let h2 = result.root.children[0] as? HeaderNode,
          let h1 = result.root.children[1] as? HeaderNode,
          let h3 = result.root.children[2] as? HeaderNode
    else { Issue.record("Expected HeaderNodes"); return }
    #expect(h2.level == 2)
    #expect(h1.level == 1)
    #expect(h3.level == 3)
    // Empty headings should have no text content
    let t2 = h2.children.compactMap { ($0 as? TextNode)?.content }.joined()
    let t1 = h1.children.compactMap { ($0 as? TextNode)?.content }.joined()
    let t3 = h3.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(t2.isEmpty)
    #expect(t1.isEmpty)
    #expect(t3.isEmpty)
  }
}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Thematic Breaks")
struct MarkdownThematicBreaksTests {
  private let h = MarkdownTestHarness()

  // 12: Precedence — list parsing prevents code span across items; backticks remain literal
  @Test("Spec 12: list precedence over code span across lines")
  func spec12() {
    let input = "- `one\n- two`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect a single unordered list with two items
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 2)
    guard let li1 = ul.children[0] as? ListItemNode, let li2 = ul.children[1] as? ListItemNode
    else {
      Issue.record("Expected two ListItemNode")
      return
    }
    // Each list item should contain a paragraph with literal backticks, not InlineCode
    #expect(findNodes(in: li1, ofType: InlineCodeNode.self).isEmpty)
    #expect(findNodes(in: li2, ofType: InlineCodeNode.self).isEmpty)
    if let p1 = findNodes(in: li1, ofType: ParagraphNode.self).first {
      #expect(innerText(p1) == "`one")
    } else {
      Issue.record("Missing paragraph in first list item")
    }
    if let p2 = findNodes(in: li2, ofType: ParagraphNode.self).first {
      #expect(innerText(p2) == "two`")
    } else {
      Issue.record("Missing paragraph in second list item")
    }
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"`one\")]],list_item[paragraph[text(\"two`\")]]]]"
    )
  }

  // 13: basic thematic breaks with ***, --- and ___
  @Test("Spec 13: three kinds of thematic breaks are recognized")
  func spec13() {
    let input = "***\n---\n___\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Exactly three ThematicBreakNode at top level
    #expect(result.root.children.count == 3)
    #expect(result.root.children.allSatisfy { $0 is ThematicBreakNode })
    #expect(sig(result.root) == "document[thematic_break,thematic_break,thematic_break]")
  }

  // 14: +++ is not a thematic break -> paragraph
  @Test("Spec 14: '+++' is a paragraph, not a thematic break")
  func spec14() {
    let input = "+++\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "+++")
    #expect(sig(result.root) == "document[paragraph[text(\"+++\")]]")
  }

  // 15: === is not a thematic break -> paragraph
  @Test("Spec 15: '===' is a paragraph, not a thematic break")
  func spec15() {
    let input = "===\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "===")
    #expect(sig(result.root) == "document[paragraph[text(\"===\")]]")
  }

  // 16: fewer than 3 markers -> paragraph with the literal lines
  @Test("Spec 16: '--', '**', '__' lines are paragraphs, not thematic breaks")
  func spec16() {
    let input = "--\n**\n__\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Ensure no ThematicBreakNode present
    #expect(findNodes(in: result.root, ofType: ThematicBreakNode.self).isEmpty)
    // Content consists of three lines literal
    let text = innerText(p)
    #expect(text == "-- ** __")
    // Deterministic signature: merged soft line breaks become spaces
    #expect(sig(result.root) == "document[paragraph[text(\"-- ** __\")]]")
  }

  // 17: up to three leading spaces are allowed
  @Test("Spec 17: indented (≤3 spaces) thematic breaks are recognized")
  func spec17() {
    let input = " ***\n  ***\n   ***\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children.allSatisfy { $0 is ThematicBreakNode })
    #expect(sig(result.root) == "document[thematic_break,thematic_break,thematic_break]")
  }

  // 18: 4 spaces turns it into an indented code block
  @Test("Spec 18: 4-space indented '***' is an indented code block")
  func spec18() {
    let input = "    ***\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "***")
    #expect(sig(result.root) == "document[code_block(\"***\")]")
  }

  // 19: an indented thematic-break-looking line cannot interrupt a paragraph
  @Test("Spec 19: indented '***' cannot interrupt paragraph")
  func spec19() {
    let input = "Foo\n    ***\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Single paragraph, no code block, no thematic break
    #expect(result.root.children.count == 1)
    #expect(findNodes(in: result.root, ofType: ThematicBreakNode.self).isEmpty)
    #expect(findNodes(in: result.root, ofType: CodeBlockNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Combined text should contain both lines (newline handling delegated to parser; we just ensure both tokens present)
    let t = innerText(p)
    #expect(t == "Foo ***")
    #expect(sig(result.root) == "document[paragraph[text(\"Foo ***\")]]")
  }

  // 20: a long line of underscores is a thematic break
  @Test("Spec 20: many underscores is a thematic break")
  func spec20() {
    let input = "_____________________________________\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }

  // 21: spaced hyphens
  @Test("Spec 21: spaced hyphens form a thematic break")
  func spec21() {
    let input = " - - -\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }

  // 22: complex spacing with asterisks still forms a thematic break
  @Test("Spec 22: spaced asterisks form a thematic break")
  func spec22() {
    let input = " **  * ** * ** * **\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }

  // 23: hyphens with varying spaces
  @Test("Spec 23: hyphens with varying spaces form a thematic break")
  func spec23() {
    let input = "-     -      -      -\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }

  // 24: trailing spaces allowed
  @Test("Spec 24: trailing spaces allowed on thematic break line")
  func spec24() {
    let input = "- - - -    \n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
    #expect(sig(result.root) == "document[thematic_break]")
  }

  // 25: additional non-space characters disqualify thematic break
  @Test("Spec 25: extra characters prevent thematic break (3 paragraphs)")
  func spec25() {
    let input = "_ _ _ _ a\n\n\na------\n\n---a---\n"
    // Note: commonmark-spec shows blank lines between paragraphs
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect three top-level paragraphs with the exact texts
    let paras = result.root.children.compactMap { $0 as? ParagraphNode }
    #expect(paras.count == 3)
    if paras.count == 3 {
      #expect(innerText(paras[0]) == "_ _ _ _ a")
      #expect(innerText(paras[1]) == "a------")
      #expect(innerText(paras[2]) == "---a---")
    }
    #expect(findNodes(in: result.root, ofType: ThematicBreakNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"_ _ _ _ a\")],paragraph[text(\"a------\")],paragraph[text(\"---a---\")]]"
    )
  }

  // 26: '*-*' is emphasis, not thematic break
  @Test("Spec 26: '*-*' parses as emphasis around '-' in a paragraph")
  func spec26() {
    let input = " *-*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let em = p.children.first(where: { $0 is EmphasisNode }) as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    if let t = em.children.first as? TextNode { #expect(t.content == "-") }
    #expect(sig(result.root) == "document[paragraph[emphasis[text(\"-\")]]]")
  }

  // 27: hr between two lists
  @Test("Spec 27: thematic break between two lists")
  func spec27() {
    let input = "- foo\n***\n- bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let list1 = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected first UL")
      return
    }
    #expect(list1.children.count == 1)
    #expect(result.root.children[1] is ThematicBreakNode)
    guard let list2 = result.root.children[2] as? UnorderedListNode else {
      Issue.record("Expected second UL")
      return
    }
    #expect(list2.children.count == 1)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],thematic_break,unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 28: hr between paragraphs
  @Test("Spec 28: thematic break between two paragraphs")
  func spec28() {
    let input = "Foo\n***\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ParagraphNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(result.root.children[2] is ParagraphNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\")],thematic_break,paragraph[text(\"bar\")]]")
  }

  // 29: setext heading takes precedence over thematic break
  @Test("Spec 29: '---' under text makes a setext h2, not a thematic break")
  func spec29() {
    let input = "Foo\n---\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let h2 = result.root.children[0] as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h2.level == 2)
    if let t = findNodes(in: h2, ofType: TextNode.self).first { #expect(t.content == "Foo") }
    #expect(result.root.children[1] is ParagraphNode)
    #expect(
      sig(result.root) == "document[heading(level:2)[text(\"Foo\")],paragraph[text(\"bar\")]]")
  }

  // 30: hr breaks out of list context
  @Test("Spec 30: hr between list items (separate lists)")
  func spec30() {
    let input = "* Foo\n* * *\n* Bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    #expect(result.root.children[2] is UnorderedListNode)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]]],thematic_break,unordered_list(level:1)[list_item[paragraph[text(\"Bar\")]]]]"
    )
  }

  // 31: hr as content of a list item
  @Test("Spec 31: hr can be the content of a list item")
  func spec31() {
    let input = "- Foo\n- * * *\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 2)
    guard let li1 = ul.children[0] as? ListItemNode, let li2 = ul.children[1] as? ListItemNode
    else {
      Issue.record("Expected two ListItemNode")
      return
    }
    #expect(li1.children.first is ParagraphNode)
    // Second list item contains exactly a ThematicBreakNode
    #expect(childrenTypes(li2) == [.thematicBreak])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")]],list_item[thematic_break]]]"
    )
  }
}

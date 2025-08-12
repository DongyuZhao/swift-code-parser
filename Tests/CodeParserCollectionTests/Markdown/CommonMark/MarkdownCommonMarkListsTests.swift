import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Lists (Strict)")
struct MarkdownCommonMarkListsTests {
  private let h = MarkdownTestHarness()

  @Test("Unordered list with exact structure")
  func unorderedList() {
    let input = "- Item 1\n- Item 2\n- Item 3"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let ulist = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ulist.children.count == 3)
    for (index, child) in ulist.children.enumerated() {
      guard let listItem = child as? ListItemNode else {
        Issue.record("Expected ListItemNode at index \(index)")
        continue
      }
      #expect(listItem.children.count == 1)
      guard let para = listItem.children.first as? ParagraphNode else {
        Issue.record("Expected ParagraphNode in list item \(index)")
        continue
      }
      #expect(para.children.count == 1)
      guard let text = para.children.first as? TextNode else {
        Issue.record("Expected TextNode in paragraph for item \(index)")
        continue
      }
      #expect(text.content == "Item \(index + 1)")
    }
  }

  @Test("Ordered list with custom start")
  func orderedListWithCustomStart() {
    let input = "7. Item 7\n8. Item 8\n9. Item 9"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let olist = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(olist.start == 7)
    #expect(olist.children.count == 3)
    for (index, child) in olist.children.enumerated() {
      guard let listItem = child as? ListItemNode else {
        Issue.record("Expected ListItemNode at index \(index)")
        continue
      }
      guard let para = listItem.children.first as? ParagraphNode,
            let text = para.children.first as? TextNode else {
        Issue.record("Expected paragraph with text in ordered list item \(index)")
        continue
      }
      #expect(text.content == "Item \(7 + index)")
    }
  }
}

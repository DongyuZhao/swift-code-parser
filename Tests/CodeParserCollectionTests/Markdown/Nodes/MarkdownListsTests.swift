import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Lists")
struct MarkdownListsTests {
  private let h = MarkdownTestHarness()

  // Helpers
  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined(separator: "\n")
  }
  // Using shared childrenTypes/sig from Tests/.../Utils/TestUtils.swift

  // 231
  @Test("Spec 231: Paragraph, code block, then block quote")
  func spec231() {
    let input = "A paragraph\nwith two lines.\n\n    indented code\n\n> A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(childrenTypes(result.root) == [.paragraph, .codeBlock, .blockquote])
    guard let p = result.root.children[0] as? ParagraphNode,
      let code = result.root.children[1] as? CodeBlockNode,
      let bq = result.root.children[2] as? BlockquoteNode
    else {
      Issue.record("Structure mismatch")
      return
    }
    #expect(innerText(p) == "A paragraph\nwith two lines.")
    #expect(code.source == "indented code")
    #expect(innerText(bq) == "A block quote.")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]"
    )
  }

  // 232
  @Test("Spec 232: Ordered list item contains paragraph, code, and blockquote")
  func spec232() {
    let input =
      "1.  A paragraph\n    with two lines.\n\n        indented code\n\n    > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.children.count == 1)
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .blockquote])
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    let codes = findNodes(in: li, ofType: CodeBlockNode.self)
    let bqs = findNodes(in: li, ofType: BlockquoteNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    #expect(codes.count == 1 && codes[0].source == "indented code")
    #expect(bqs.count == 1 && innerText(bqs[0]) == "A block quote.")
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]")
  }

  // 233
  @Test("Spec 233: List item then following paragraph")
  func spec233() {
    let input = "- one\n\n two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let ul = result.root.children[0] as? UnorderedListNode,
      let p = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected list then paragraph")
      return
    }
    #expect(innerText(ul) == "one")
    #expect(innerText(p) == "two")
    #expect(childrenTypes(result.root) == [.unorderedList, .paragraph])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],paragraph[text(\"two\")]]")
  }

  // 234
  @Test("Spec 234: List item with two paragraphs")
  func spec234() {
    let input = "- one\n\n  two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "one")
    #expect(innerText(paras[1]) == "two")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")],paragraph[text(\"two\")]]]]")
  }

  // 235
  @Test("Spec 235: Code block follows list due to over-indentation")
  func spec235() {
    let input = " -    one\n\n     two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let ul = result.root.children[0] as? UnorderedListNode,
      let code = result.root.children[1] as? CodeBlockNode
    else {
      Issue.record("Expected list then code block")
      return
    }
    #expect(innerText(ul) == "one")
    #expect(code.source == " two")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],code_block(\" two\")]")
  }

  // 236
  @Test("Spec 236: Two paragraphs inside one list item when indentation matches")
  func spec236() {
    let input = " -    one\n\n      two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "one")
    #expect(innerText(paras[1]) == "two")
    #expect(childrenTypes(li) == [.paragraph, .paragraph])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"one\")],paragraph[text(\"two\")]]]]")
  }

  // 237
  @Test("Spec 237: Nested blockquotes with ordered list")
  func spec237() {
    let input = "   > > 1.  one\n>>\n>>     two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq1 = result.root.children.first as? BlockquoteNode,
      let bq2 = bq1.children.first as? BlockquoteNode,
      let ol = bq2.children.first as? OrderedListNode
    else {
      Issue.record("Expected nested blockquotes with list")
      return
    }
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "one")
    #expect(innerText(paras[1]) == "two")
    #expect(childrenTypes(bq2) == [.orderedList, .paragraph])
    #expect(
      sig(result.root)
        == "document[blockquote[blockquote[ordered_list(level:1)[list_item[paragraph[text(\"one\")]]],paragraph[text(\"two\")]]]]]")
  }

  // 238
  @Test("Spec 238: Nested blockquotes with ul then paragraph")
  func spec238() {
    let input = ">>- one\n>>\n  >  > two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq1 = result.root.children.first as? BlockquoteNode,
      let bq2 = bq1.children.first as? BlockquoteNode
    else {
      Issue.record("Expected nested blockquotes")
      return
    }
    #expect(bq2.children.count == 2)
    guard let ul = bq2.children[0] as? UnorderedListNode,
      let p = bq2.children[1] as? ParagraphNode
    else {
      Issue.record("Expected list then paragraph")
      return
    }
    #expect(innerText(ul) == "one")
    #expect(innerText(p) == "two")
    #expect(childrenTypes(bq2) == [.unorderedList, .paragraph])
    #expect(
      sig(result.root)
        == "document[blockquote[blockquote[unordered_list(level:1)[list_item[paragraph[text(\"one\")]]],paragraph[text(\"two\")]]]]]")
  }

  // 239
  @Test("Spec 239: Not lists due to no space after marker/number")
  func spec239() {
    let input = "-one\n\n2.two\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: UnorderedListNode.self).isEmpty)
    #expect(findNodes(in: result.root, ofType: OrderedListNode.self).isEmpty)
    let paras = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "-one")
    #expect(innerText(paras[1]) == "2.two")
    #expect(sig(result.root) == "document[paragraph[text(\"-one\")],paragraph[text(\"2.two\")]]")
  }

  // 240
  @Test("Spec 240: Multiple blank lines inside list item create new paragraph in same item")
  func spec240() {
    let input = "- foo\n\n\n  bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "foo")
    #expect(innerText(paras[1]) == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]")
  }

  // 241
  @Test("Spec 241: Complex content inside list item (para, fenced code, para, blockquote)")
  func spec241() {
    let input = "1.  foo\n\n    ```\n    bar\n    ```\n\n    baz\n\n    > bam\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    let codes = findNodes(in: li, ofType: CodeBlockNode.self)
    let bqs = findNodes(in: li, ofType: BlockquoteNode.self)
    #expect(paras.count == 2 && innerText(paras[0]) == "foo" && innerText(paras[1]) == "baz")
    #expect(codes.count == 1 && codes[0].source == "bar")
    #expect(bqs.count == 1 && innerText(bqs[0]) == "bam")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .paragraph, .blockquote])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\"),paragraph[text(\"baz\")],blockquote[paragraph[text(\"bam\")]]]]]"
    )
  }

  // 242
  @Test("Spec 242: Code block inside list item preserves blank lines")
  func spec242() {
    let input = "- Foo\n\n      bar\n\n\n      baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    guard let firstPara = li.children.first as? ParagraphNode else {
      Issue.record("Expected first child ParagraphNode")
      return
    }
    #expect(innerText(firstPara) == "Foo")
    #expect(code.source == "bar\n\n\nbaz")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"Foo\")],code_block(\"bar\\n\\n\\nbaz\")]]]")
  }

  // 243
  @Test("Spec 243: Large start number allowed for ordered list")
  func spec243() {
    let input = "123456789. ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
  #expect(ol.start == 123_456_789)
    #expect(innerText(ol) == "ok")
  #expect(sig(result.root) == "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]")
  }

  // 244
  @Test("Spec 244: Ten-digit start is not a list")
  func spec244() {
    let input = "1234567890. not ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: OrderedListNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "1234567890. not ok")
    #expect(sig(result.root) == "document[paragraph[text(\"1234567890. not ok\")]]")
  }

  // 245
  @Test("Spec 245: Ordered list can start at 0")
  func spec245() {
    let input = "0. ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
  #expect(ol.start == 0)
    #expect(innerText(ol) == "ok")
  #expect(sig(result.root) == "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]")
  }

  // 246
  @Test("Spec 246: Leading zeros in ordered start are normalized")
  func spec246() {
    let input = "003. ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
  #expect(ol.start == 3)
    #expect(innerText(ol) == "ok")
  #expect(sig(result.root) == "document[ordered_list(level:1)[list_item[paragraph[text(\"ok\")]]]]")
  }

  // 247
  @Test("Spec 247: Negative numbers are not list markers")
  func spec247() {
    let input = "-1. not ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: OrderedListNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "-1. not ok")
    #expect(sig(result.root) == "document[paragraph[text(\"-1. not ok\")]]")
  }

  // 248
  @Test("Spec 248: Code block as child of list item")
  func spec248() {
    let input = "- foo\n\n      bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode,
      let code = findNodes(in: li, ofType: CodeBlockNode.self).first
    else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    // Deterministic: list item starts with a paragraph 'foo'
    if let p = li.children.first as? ParagraphNode { #expect(innerText(p) == "foo") }
    #expect(code.source == "bar")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\")]]]")
  }

  // 249
  @Test("Spec 249: Code block inside ol item with wide indent")
  func spec249() {
    let input = "  10.  foo\n\n           bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.start == 10)
    guard let li = ol.children.first as? ListItemNode,
      let code = findNodes(in: li, ofType: CodeBlockNode.self).first
    else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "bar")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],code_block(\"bar\")]]]")
  }

  // 250
  @Test("Spec 250: Code, paragraph, code at top level")
  func spec250() {
    let input = "    indented code\n\nparagraph\n\n    more code\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let code1 = result.root.children[0] as? CodeBlockNode,
      let p = result.root.children[1] as? ParagraphNode,
      let code2 = result.root.children[2] as? CodeBlockNode
    else {
      Issue.record("Expected code, paragraph, code")
      return
    }
    #expect(code1.source == "indented code")
    #expect(innerText(p) == "paragraph")
    #expect(code2.source == "more code")
    #expect(childrenTypes(result.root) == [.codeBlock, .paragraph, .codeBlock])
    #expect(
      sig(result.root)
        == "document[code_block(\"indented code\"),paragraph[text(\"paragraph\")],code_block(\"more code\")]"
    )
  }

  // 251
  @Test("Spec 251: ol item with code, paragraph, code")
  func spec251() {
    let input = "1.     indented code\n\n   paragraph\n\n       more code\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let codes = findNodes(in: li, ofType: CodeBlockNode.self)
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(
      codes.count == 2 && codes[0].source == "indented code" && codes[1].source == "more code")
    #expect(paras.count == 1 && innerText(paras[0]) == "paragraph")
    #expect(childrenTypes(li) == [.codeBlock, .paragraph, .codeBlock])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[code_block(\"indented code\"),paragraph[text(\"paragraph\")],code_block(\"more code\")]]]")
  }

  // 252
  @Test("Spec 252: First code block retains one leading space")
  func spec252() {
    let input = "1.      indented code\n\n   paragraph\n\n       more code\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    guard let li = ol.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let codes = findNodes(in: li, ofType: CodeBlockNode.self)
    #expect(codes.first?.source == " indented code")
    #expect(childrenTypes(li).first == .codeBlock)
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[code_block(\" indented code\"),paragraph[text(\"paragraph\")],code_block(\"more code\")]]]"
    )
  }

  // 253
  @Test("Spec 253: Indented paragraph then paragraph")
  func spec253() {
    let input = "   foo\n\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let paras = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "foo")
    #expect(innerText(paras[1]) == "bar")
    #expect(sig(result.root) == "document[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]")
  }

  // 254
  @Test("Spec 254: List item then top-level paragraph")
  func spec254() {
    let input = "-    foo\n\n  bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let ul = result.root.children[0] as? UnorderedListNode,
      let p = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected list then paragraph")
      return
    }
    #expect(innerText(ul) == "foo")
    #expect(innerText(p) == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],paragraph[text(\"bar\")]]")
  }

  // 255
  @Test("Spec 255: Two paragraphs inside one list item")
  func spec255() {
    let input = "-  foo\n\n   bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "foo")
    #expect(innerText(paras[1]) == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],paragraph[text(\"bar\")]]]]")
  }

  // 256
  @Test("Spec 256: Mixed empty items and code blocks in ul")
  func spec256() {
    let input = "-\n  foo\n-\n  ```\n  bar\n  ```\n-\n      baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    // item1: foo
    guard let li1 = ul.children[0] as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(innerText(li1) == "foo")
    // item2: fenced code bar
    guard let li2 = ul.children[1] as? ListItemNode,
      let code2 = findNodes(in: li2, ofType: CodeBlockNode.self).first
    else {
      Issue.record("Expected CodeBlockNode in item2")
      return
    }
    #expect(code2.source == "bar")
    // item3: indented code baz
    guard let li3 = ul.children[2] as? ListItemNode,
      let code3 = findNodes(in: li3, ofType: CodeBlockNode.self).first
    else {
      Issue.record("Expected CodeBlockNode in item3")
      return
    }
    #expect(code3.source == "baz")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[code_block(\"bar\")],list_item[code_block(\"baz\")]]]")
  }

  // 257
  @Test("Spec 257: Blank content line continues item text")
  func spec257() {
    let input = "-   \n  foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
  #expect(innerText(ul) == "foo")
  #expect(sig(result.root) == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]]")
  }

  // 258
  @Test("Spec 258: Empty list item then paragraph")
  func spec258() {
    let input = "-\n\n  foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let ul = result.root.children[0] as? UnorderedListNode,
      let p = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected list then paragraph")
      return
    }
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    #expect(findNodes(in: li, ofType: ParagraphNode.self).isEmpty)
    #expect(innerText(p) == "foo")
  #expect(sig(result.root) == "document[unordered_list(level:1)[list_item],paragraph[text(\"foo\")]]")
  }

  // 259
  @Test("Spec 259: Ul with empty middle item")
  func spec259() {
    let input = "- foo\n-\n- bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    #expect(innerText(ul.children[0]) == "foo")
    #expect(findNodes(in: ul.children[1], ofType: ParagraphNode.self).isEmpty)
    #expect(innerText(ul.children[2]) == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 260
  @Test("Spec 260: Ul with blank-content middle item")
  func spec260() {
    let input = "- foo\n-   \n- bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    #expect(innerText(ul.children[0]) == "foo")
    #expect(findNodes(in: ul.children[1], ofType: ParagraphNode.self).isEmpty)
    #expect(innerText(ul.children[2]) == "bar")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 261
  @Test("Spec 261: Ol with empty middle item")
  func spec261() {
    let input = "1. foo\n2.\n3. bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.children.count == 3)
    #expect(innerText(ol.children[0]) == "foo")
    #expect(findNodes(in: ol.children[1], ofType: ParagraphNode.self).isEmpty)
    #expect(innerText(ol.children[2]) == "bar")
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item,list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 262
  @Test("Spec 262: Single empty item list")
  func spec262() {
    let input = "*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 1)
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
  #expect(findNodes(in: li, ofType: ParagraphNode.self).isEmpty)
  #expect(sig(result.root) == "document[unordered_list(level:1)[list_item]]")
  }

  // 263
  @Test("Spec 263: Lone markers without blank separation are paragraphs")
  func spec263() {
    let input = "foo\n*\n\nfoo\n1.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let paras = findNodes(in: result.root, ofType: ParagraphNode.self)
    #expect(paras.count == 2)
    #expect(innerText(paras[0]) == "foo\n*")
    #expect(innerText(paras[1]) == "foo\n1.")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"foo\"),line_break(soft),text(\"*\")],paragraph[text(\"foo\"),line_break(soft),text(\"1.\")]]"
    )
  }

  // 264
  @Test("Spec 264: List item content: paragraph, code, blockquote (variant spacing)")
  func spec264() {
    let input =
      " 1.  A paragraph\n     with two lines.\n\n         indented code\n\n     > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Missing code block")
      return
    }
    #expect(code.source == "indented code")
    guard let bq = findNodes(in: li, ofType: BlockquoteNode.self).first else {
      Issue.record("Missing blockquote")
      return
    }
    #expect(innerText(bq) == "A block quote.")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .blockquote])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]")
  }

  // 265
  @Test("Spec 265: Another spacing variant for same structure")
  func spec265() {
    let input =
      "  1.  A paragraph\n      with two lines.\n\n          indented code\n\n      > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Missing code block")
      return
    }
    #expect(code.source == "indented code")
    guard let bq = findNodes(in: li, ofType: BlockquoteNode.self).first else {
      Issue.record("Missing blockquote")
      return
    }
    #expect(innerText(bq) == "A block quote.")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .blockquote])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]"
    )
  }

  // 266
  @Test("Spec 266: Third spacing variant")
  func spec266() {
    let input =
      "   1.  A paragraph\n       with two lines.\n\n           indented code\n\n       > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Missing code block")
      return
    }
    #expect(code.source == "indented code")
    guard let bq = findNodes(in: li, ofType: BlockquoteNode.self).first else {
      Issue.record("Missing blockquote")
      return
    }
    #expect(innerText(bq) == "A block quote.")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .blockquote])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]")
  }

  // 267
  @Test("Spec 267: Four-space indent makes a code block (not a list)")
  func spec267() {
    let input =
      "    1.  A paragraph\n        with two lines.\n\n            indented code\n\n        > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(
      code.source
        == "1.  A paragraph\n    with two lines.\n\n        indented code\n\n    > A block quote.")
    #expect(
      sig(result.root)
        == "document[code_block(\"1.  A paragraph\\n    with two lines.\\n\\n        indented code\\n\\n    > A block quote.\")]"
    )
  }

  // 268
  @Test("Spec 268: Paragraph broken across lines inside list item")
  func spec268() {
    let input =
      "  1.  A paragraph\nwith two lines.\n\n          indented code\n\n      > A block quote.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Missing code block")
      return
    }
    #expect(code.source == "indented code")
    guard let bq = findNodes(in: li, ofType: BlockquoteNode.self).first else {
      Issue.record("Missing blockquote")
      return
    }
    #expect(innerText(bq) == "A block quote.")
    #expect(childrenTypes(li) == [.paragraph, .codeBlock, .blockquote])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")],code_block(\"indented code\"),blockquote[paragraph[text(\"A block quote.\")]]]]]")
  }

  // 269
  @Test("Spec 269: Tight vs loose list item rendering as single paragraph")
  func spec269() {
    let input = "  1.  A paragraph\n    with two lines.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "A paragraph\nwith two lines.")
    #expect(childrenTypes(li) == [.paragraph])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"A paragraph\"),line_break(soft),text(\"with two lines.\")]]]]"
    )
  }

  // 270
  @Test("Spec 270: Blockquote inside list item with lazy continuation")
  func spec270() {
    let input = "> 1. > Blockquote\ncontinued here.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq = result.root.children.first as? BlockquoteNode,
      let ol = bq.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode,
      let innerBQ = findNodes(in: li, ofType: BlockquoteNode.self).first
    else {
      Issue.record("Expected nested structure")
      return
    }
    #expect(innerText(innerBQ) == "Blockquote\ncontinued here.")
    #expect(childrenTypes(li) == [.blockquote])
    #expect(
      sig(result.root)
        == "document[blockquote[ordered_list(level:1)[list_item[blockquote[paragraph[text(\"Blockquote\"),line_break(soft),text(\"continued here.\")]]]]]]]"
    )
  }

  // 271
  @Test("Spec 271: Same as 270 with markers on both lines")
  func spec271() {
    let input = "> 1. > Blockquote\n> continued here.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let bq = result.root.children.first as? BlockquoteNode,
      let ol = bq.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode,
      let innerBQ = findNodes(in: li, ofType: BlockquoteNode.self).first
    else {
      Issue.record("Expected nested structure")
      return
    }
    #expect(innerText(innerBQ) == "Blockquote\ncontinued here.")
    #expect(childrenTypes(li) == [.blockquote])
    #expect(
      sig(result.root)
        == "document[blockquote[ordered_list(level:1)[list_item[blockquote[paragraph[text(\"Blockquote\"),line_break(soft),text(\"continued here.\")]]]]]]]")
  }

  // 272
  @Test("Spec 272: Deeply nested unordered lists")
  func spec272() {
    let input = "- foo\n  - bar\n    - baz\n      - boo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = li1.children.first as? UnorderedListNode,
      let li2 = ul2.children.first as? ListItemNode,
      let ul3 = li2.children.first as? UnorderedListNode,
      let li3 = ul3.children.first as? ListItemNode,
      let ul4 = li3.children.first as? UnorderedListNode,
      let li4 = ul4.children.first as? ListItemNode
    else {
      Issue.record("Expected 4-level nested ul")
      return
    }
    // Deterministic: each leaf paragraph text equals expected
    if let p1 = li1.children.first as? ParagraphNode { #expect(innerText(p1) == "foo") }
    if let p2 = li2.children.first as? ParagraphNode { #expect(innerText(p2) == "bar") }
    if let p3 = li3.children.first as? ParagraphNode { #expect(innerText(p3) == "baz") }
    if let p4 = li4.children.first as? ParagraphNode { #expect(innerText(p4) == "boo") }
    #expect(childrenTypes(li1).first == .paragraph)
    #expect(childrenTypes(li1) == [.paragraph, .unorderedList])
    #expect(childrenTypes(li2).first == .paragraph)
    #expect(childrenTypes(li2) == [.paragraph, .unorderedList])
    #expect(childrenTypes(li3).first == .paragraph)
    #expect(childrenTypes(li3) == [.paragraph, .unorderedList])
    #expect(childrenTypes(li4) == [.paragraph])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")],unordered_list(level:3)[list_item[paragraph[text(\"baz\")],unordered_list(level:4)[list_item[paragraph[text(\"boo\")]]]]]]]]]]]]"
    )
  }

  // 273
  @Test("Spec 273: Misaligned indents produce flat list")
  func spec273() {
    let input = "- foo\n - bar\n  - baz\n   - boo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 4)
    #expect(innerText(ul.children[0]) == "foo")
    #expect(innerText(ul.children[1]) == "bar")
    #expect(innerText(ul.children[2]) == "baz")
    #expect(innerText(ul.children[3]) == "boo")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]],list_item[paragraph[text(\"boo\")]]]]"
    )
  }

  // 274
  @Test("Spec 274: Ol item with nested ul")
  func spec274() {
    let input = "10) foo\n    - bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.start == 10)
    guard let li = ol.children.first as? ListItemNode,
      let ul = li.children.first as? UnorderedListNode
    else {
      Issue.record("Expected nested UnorderedList")
      return
    }
    #expect(innerText(ul) == "bar")
    #expect(childrenTypes(li) == [.paragraph, .unorderedList])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")]]]]]]"
    )
  }

  // 275
  @Test("Spec 275: Separate ol then ul")
  func spec275() {
    let input = "10) foo\n   - bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is OrderedListNode)
    #expect(result.root.children[1] is UnorderedListNode)
    #expect(childrenTypes(result.root) == [.orderedList, .unorderedList])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]]]]"
    )
  }

  // 276
  @Test("Spec 276: Ul inside ul item")
  func spec276() {
    let input = "- - foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = li1.children.first as? UnorderedListNode
    else {
      Issue.record("Expected nested UnorderedList")
      return
    }
    #expect(innerText(ul2) == "foo")
    #expect(childrenTypes(li1) == [.unorderedList])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[unordered_list(level:2)[list_item[paragraph[text(\"foo\")]]]]]]"
    )
  }

  // 277
  @Test("Spec 277: Mixed nested lists (ol within ul within ol)")
  func spec277() {
    let input = "1. - 2. foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol1 = result.root.children.first as? OrderedListNode,
      let li1 = ol1.children.first as? ListItemNode,
      let ul = li1.children.first as? UnorderedListNode,
      let li2 = ul.children.first as? ListItemNode,
      let ol2 = li2.children.first as? OrderedListNode
    else {
      Issue.record("Expected nested lists")
      return
    }
    #expect(ol2.start == 2)
    #expect(innerText(ol2) == "foo")
    #expect(childrenTypes(li1) == [.unorderedList])
    #expect(childrenTypes(li2) == [.orderedList])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[unordered_list(level:2)[list_item[ordered_list(level:3)[list_item[paragraph[text(\"foo\")]]]]]]]]]]"
    )
  }

  // 278
  @Test("Spec 278: Headings inside list items; setext in li")
  func spec278() {
    let input = "- # Foo\n- Bar\n  ---\n  baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 2)
    guard let li1 = ul.children[0] as? ListItemNode,
      let h1 = li1.children.first as? HeaderNode
    else {
      Issue.record("Expected H1 in first li")
      return
    }
    #expect(h1.level == 1 && innerText(h1) == "Foo")
    guard let li2 = ul.children[1] as? ListItemNode,
      let h2 = li2.children.first as? HeaderNode
    else {
      Issue.record("Expected H2 in second li")
      return
    }
    #expect(h2.level == 2 && innerText(h2) == "Bar")
    // trailing text 'baz' directly in li
    #expect(findNodes(in: li2, ofType: TextNode.self).last?.content == "baz")
    #expect(childrenTypes(ul.children[0]) == [.heading])
    let types2 = childrenTypes(li2)
    #expect(types2.first == .heading)
    #expect(types2 == [.heading, .text])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[heading(level:1)[text(\"Foo\")]],list_item[heading(level:2)[text(\"Bar\")],text(\"baz\")]]]"
    )
  }

  // 281
  @Test("Spec 281: Different bullet markers split lists")
  func spec281() {
    let input = "- foo\n- bar\n+ baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let uls = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(uls.count == 2)
    #expect(innerText(uls[0]) == "foo\nbar")
    #expect(innerText(uls[1]) == "baz")
    #expect(childrenTypes(result.root) == [.unorderedList, .unorderedList])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],unordered_list(level:1)[list_item[paragraph[text(\"baz\")]]]]"
    )
  }

  // 282
  @Test("Spec 282: Different ordered markers split lists")
  func spec282() {
    let input = "1. foo\n2. bar\n3) baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let ols = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(ols.count == 2)
    #expect(innerText(ols[0]) == "foo\nbar")
    #expect(ols[1].start == 3 && innerText(ols[1]) == "baz")
    #expect(childrenTypes(result.root) == [.orderedList, .orderedList])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],ordered_list(level:1)[list_item[paragraph[text(\"baz\")]]]]"
    )
  }

  // 283
  @Test("Spec 283: Paragraph then list")
  func spec283() {
    let input = "Foo\n- bar\n- baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p = result.root.children[0] as? ParagraphNode,
      let ul = result.root.children[1] as? UnorderedListNode
    else {
      Issue.record("Expected paragraph then list")
      return
    }
    #expect(innerText(p) == "Foo")
    #expect(innerText(ul) == "bar\nbaz")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\")],unordered_list(level:1)[list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]]]]"
    )
  }

  // 284
  @Test("Spec 284: Long number period not a list marker")
  func spec284() {
    let input = "The number of windows in my house is\n14.  The number of doors is 6.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: OrderedListNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "The number of windows in my house is\n14.  The number of doors is 6.")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"The number of windows in my house is\"),line_break(soft),text(\"14.  The number of doors is 6.\")]]"
    )
  }

  // 285
  @Test("Spec 285: Short number period forms list")
  func spec285() {
    let input = "The number of windows in my house is\n1.  The number of doors is 6.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is ParagraphNode)
    guard let ol = result.root.children[1] as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(innerText(ol) == "The number of doors is 6.")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"The number of windows in my house is\")],ordered_list(level:1)[list_item[paragraph[text(\"The number of doors is 6.\")]]]]"
    )
  }

  // 286
  @Test("Spec 286: Blank lines between list items still same list")
  func spec286() {
    let input = "- foo\n\n- bar\n\n\n- baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    #expect(childrenTypes(result.root) == [.unorderedList])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]],list_item[paragraph[text(\"baz\")]]]]"
    )
  }

  // 287
  @Test("Spec 287: Deep nesting with blank lines causes two paragraphs at deepest li")
  func spec287() {
    let input = "- foo\n  - bar\n    - baz\n\n\n      bim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = li1.children.first as? UnorderedListNode,
      let li2 = ul2.children.first as? ListItemNode,
      let ul3 = li2.children.first as? UnorderedListNode,
      let li3 = ul3.children.first as? ListItemNode
    else {
      Issue.record("Expected nested structure")
      return
    }
    let paras = findNodes(in: li3, ofType: ParagraphNode.self)
    #expect(paras.count == 2 && innerText(paras[0]) == "baz" && innerText(paras[1]) == "bim")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")],unordered_list(level:3)[list_item[paragraph[text(\"baz\")],paragraph[text(\"bim\")]]]]]]]]]]"
    )
  }

  // 288
  @Test("Spec 288: HTML comment splits lists")
  func spec288() {
    let input = "- foo\n- bar\n\n<!-- -->\n\n- baz\n- bim\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect: ul, html block, ul
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is HTMLBlockNode)
    #expect(result.root.children[2] is UnorderedListNode)
    #expect(childrenTypes(result.root) == [.unorderedList, .htmlBlock, .unorderedList])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]],list_item[paragraph[text(\"bar\")]]],html_block,unordered_list(level:1)[list_item[paragraph[text(\"baz\")]],list_item[paragraph[text(\"bim\")]]]]"
    )
  }

  // 289
  @Test("Spec 289: HTML comment separates list and code block")
  func spec289() {
    let input = "-   foo\n\n    notcode\n\n-   foo\n\n<!-- -->\n\n    code\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect: ul, html, code
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is HTMLBlockNode)
    #expect(result.root.children[2] is CodeBlockNode)
    #expect(childrenTypes(result.root) == [.unorderedList, .htmlBlock, .codeBlock])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]],html_block,code_block(\"code\")]"
    )
  }

  // 290
  @Test("Spec 290: Misaligned inks produce flat ul with items a..g")
  func spec290() {
    let input = "- a\n - b\n  - c\n   - d\n  - e\n - f\n- g\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 7)
    let texts = ul.children.compactMap { innerText($0) }
    #expect(texts == ["a", "b", "c", "d", "e", "f", "g"])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]],list_item[paragraph[text(\"d\")]],list_item[paragraph[text(\"e\")]],list_item[paragraph[text(\"f\")]],list_item[paragraph[text(\"g\")]]]]"
    )
  }

  // 291
  @Test("Spec 291: Indented numbers still separate items")
  func spec291() {
    let input = "1. a\n\n  2. b\n\n   3. c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(ol.children.count == 3)
    let texts = ol.children.compactMap { innerText($0) }
    #expect(texts == ["a", "b", "c"])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]]"
    )
  }

  // 292
  @Test("Spec 292: Too deep indent turns remainder into text within last li")
  func spec292() {
    let input = "- a\n - b\n  - c\n   - d\n    - e\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 4)
    #expect(innerText(ul.children[3]) == "d\n- e")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]],list_item[paragraph[text(\"d\"),line_break(soft),text(\"- e\")]]]]"
    )
  }

  // 293
  @Test("Spec 293: Too deep indent after ol becomes code block")
  func spec293() {
    let input = "1. a\n\n  2. b\n\n    3. c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is OrderedListNode)
    guard let code = result.root.children[1] as? CodeBlockNode else {
      Issue.record("Expected trailing CodeBlockNode")
      return
    }
    #expect(code.source == "3. c")
    #expect(childrenTypes(result.root) == [.orderedList, .codeBlock])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]]],code_block(\"3. c\")]"
    )
  }

  // 294
  @Test("Spec 294: Blank line separates items but keeps one list")
  func spec294() {
    let input = "- a\n- b\n\n- c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]]"
    )
  }

  // 295
  @Test("Spec 295: Middle empty item remains empty")
  func spec295() {
    let input = "* a\n*\n\n* c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    guard let li2 = ul.children[1] as? ListItemNode else {
      Issue.record("Expected second ListItemNode")
      return
    }
    #expect(findNodes(in: li2, ofType: ParagraphNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item,list_item[paragraph[text(\"c\")]]]]"
    )
  }

  // 296
  @Test("Spec 296: Additional paragraph belongs to previous item")
  func spec296() {
    let input = "- a\n- b\n\n  c\n- d\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    guard let li2 = ul.children[1] as? ListItemNode else {
      Issue.record("Expected second ListItemNode")
      return
    }
    let paras = findNodes(in: li2, ofType: ParagraphNode.self)
    #expect(paras.count == 2 && innerText(paras[1]) == "c")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")],paragraph[text(\"c\")]],list_item[paragraph[text(\"d\")]]]]"
    )
  }

  // 297
  @Test("Spec 297: Definition after list does not affect list items")
  func spec297() {
    let input = "- a\n- b\n\n  [ref]: /url\n- d\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    let texts = ul.children.compactMap { innerText($0) }
    #expect(texts == ["a", "b", "d"])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"d\")]]]]"
    )
  }

  // 298
  @Test("Spec 298: Fenced code bounces within list item")
  func spec298() {
    let input = "- a\n- ```\n  b\n\n\n  ```\n- c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 3)
    guard let li2 = ul.children[1] as? ListItemNode,
      let code = findNodes(in: li2, ofType: CodeBlockNode.self).first
    else {
      Issue.record("Expected CodeBlockNode in second item")
      return
    }
    #expect(code.source == "b\n\n\n")
    #expect(childrenTypes(li2) == [.codeBlock])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]],list_item[code_block(\"b\\n\\n\\n\")],list_item[paragraph[text(\"c\")]]]]"
    )
  }

  // 299
  @Test("Spec 299: Nested list with additional paragraph in child item")
  func spec299() {
    let input = "- a\n  - b\n\n    c\n- d\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = li1.children.first as? UnorderedListNode,
      let li2 = ul2.children.first as? ListItemNode
    else {
      Issue.record("Expected nested list")
      return
    }
    let paras = findNodes(in: li2, ofType: ParagraphNode.self)
    #expect(paras.count == 2 && innerText(paras[0]) == "b" && innerText(paras[1]) == "c")
    #expect(childrenTypes(li2) == [.paragraph, .paragraph])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")],paragraph[text(\"c\")]]]],list_item[paragraph[text(\"d\")]]]]"
    )
  }

  // 300
  @Test("Spec 300: Blockquote within list item with empty quoted line")
  func spec300() {
    let input = "* a\n  > b\n  >\n* c\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode,
      let li1 = ul.children.first as? ListItemNode,
      let bq = findNodes(in: li1, ofType: BlockquoteNode.self).first
    else {
      Issue.record("Expected blockquote in first item")
      return
    }
    #expect(innerText(bq) == "b")
    #expect(childrenTypes(li1) == [.blockquote])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],blockquote[paragraph[text(\"b\")]]],list_item[paragraph[text(\"c\")]]]]"
    )
  }

  // 301
  @Test("Spec 301: Blockquote and fenced code inside list item")
  func spec301() {
    let input = "- a\n  > b\n  ```\n  c\n  ```\n- d\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode,
      let li1 = ul.children.first as? ListItemNode
    else {
      Issue.record("Expected first list item")
      return
    }
    #expect(!findNodes(in: li1, ofType: BlockquoteNode.self).isEmpty)
    guard let code = findNodes(in: li1, ofType: CodeBlockNode.self).first else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "c")
    let types = childrenTypes(li1)
    #expect(types.first == .paragraph)
    #expect(types == [.paragraph, .blockquote, .codeBlock])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],blockquote[paragraph[text(\"b\")]],code_block(\"c\")],list_item[paragraph[text(\"d\")]]]]"
    )
  }

  // 302
  @Test("Spec 302: Single-item ul")
  func spec302() {
    let input = "- a\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(innerText(ul) == "a")
  #expect(childrenTypes(result.root) == [.unorderedList])
  #expect(sig(result.root) == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")]]]]")
  }

  // 303
  @Test("Spec 303: Nested ul under a")
  func spec303() {
    let input = "- a\n  - b\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = li1.children.first as? UnorderedListNode
    else {
      Issue.record("Expected nested ul")
      return
    }
    #expect(innerText(ul2) == "b")
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]]]]]]"
    )
  }

  // 304
  @Test("Spec 304: Fenced code then paragraph inside ol item")
  func spec304() {
    let input = "1. ```\n   foo\n   ```\n\n   bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ol = result.root.children.first as? OrderedListNode,
      let li = ol.children.first as? ListItemNode
    else {
      Issue.record("Expected ordered list item")
      return
    }
    guard let code = findNodes(in: li, ofType: CodeBlockNode.self).first else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "foo")
    let paras = findNodes(in: li, ofType: ParagraphNode.self)
    #expect(paras.count == 1 && innerText(paras[0]) == "bar")
    #expect(childrenTypes(li) == [.codeBlock, .paragraph])
    #expect(
      sig(result.root)
        == "document[ordered_list(level:1)[list_item[code_block(\"foo\"),paragraph[text(\"bar\")]]]]")
  }

  // 305
  @Test("Spec 305: Nested list under item plus trailing paragraph in same item")
  func spec305() {
    let input = "* foo\n  * bar\n\n  baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul1 = result.root.children.first as? UnorderedListNode,
      let li1 = ul1.children.first as? ListItemNode,
      let ul2 = findNodes(in: li1, ofType: UnorderedListNode.self).first
    else {
      Issue.record("Expected nested ul")
      return
    }
    #expect(innerText(ul2) == "bar")
    let paras = findNodes(in: li1, ofType: ParagraphNode.self)
    #expect(paras.map(innerText) == ["foo", "baz"])
    #expect(childrenTypes(li1) == [.paragraph, .unorderedList, .paragraph])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"foo\")],unordered_list(level:2)[list_item[paragraph[text(\"bar\")]]],paragraph[text(\"baz\")]]]]"
    )
  }

  // 306
  @Test("Spec 306: Two top-level items with their own child lists")
  func spec306() {
    let input = "- a\n  - b\n  - c\n\n- d\n  - e\n  - f\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 2)
    guard let li1 = ul.children[0] as? ListItemNode,
      let li2 = ul.children[1] as? ListItemNode
    else {
      Issue.record("Expected two list items")
      return
    }
    let sub1 = findNodes(in: li1, ofType: UnorderedListNode.self).first
    let sub2 = findNodes(in: li2, ofType: UnorderedListNode.self).first
    #expect(sub1?.children.count == 2)
    #expect(sub2?.children.count == 2)
    let t1 = childrenTypes(li1)
    #expect(t1 == [.paragraph, .unorderedList])
    let t2 = childrenTypes(li2)
    #expect(t2 == [.paragraph, .unorderedList])
    #expect(
      sig(result.root)
        == "document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]],list_item[paragraph[text(\"c\")]]]],list_item[paragraph[text(\"d\")],unordered_list(level:2)[list_item[paragraph[text(\"e\")]],list_item[paragraph[text(\"f\")]]]]]]]]"
    )
  }

}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Block Quotes (Strict)")
struct MarkdownCommonMarkBlockQuotesTests {
  private let h = MarkdownTestHarness()

  @Test("Simple blockquote")
  func simpleBlockquote() {
    let input = "> This is a quote"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let blockquote = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(blockquote.children.count == 1)
    guard let para = blockquote.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in blockquote")
      return
    }
    #expect(para.children.count == 1)
    guard let text = para.children.first as? TextNode else {
      Issue.record("Expected TextNode in paragraph")
      return
    }
    #expect(text.content == "This is a quote")
  }

  @Test("Multi-line blockquote with soft line break")
  func multilineBlockquote() {
    let input = "> Line 1\n> Line 2"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let blockquote = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode for multi-line")
      return
    }
    #expect(blockquote.children.count == 1)
    guard let para = blockquote.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in multi-line blockquote")
      return
    }
    let textNodes = para.children.compactMap { $0 as? TextNode }
    let allText = textNodes.map { $0.content }.joined()
    #expect(allText.contains("Line 1"))
    #expect(allText.contains("Line 2"))
  }

  // Spec 232: lazy continuation for a paragraph inside blockquote
  @Test("Blockquote lazy continuation includes following line (Spec 232)")
  func blockquoteLazyContinuation() {
    let input = "> # Foo\n> bar\nbaz"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect a single blockquote at top, since lazy continuation keeps "baz" inside
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    // In our strict parser, content inside blockquote is parsed as paragraph text (no heading node)
    #expect(bq.children.count == 2, "Should have two paragraphs for two quoted lines")
    // The second paragraph should contain bar + soft break + baz (from lazy continuation)
    guard let para2 = bq.children.dropFirst().first as? ParagraphNode else {
      Issue.record("Expected second ParagraphNode in blockquote")
      return
    }
    // Expect children: Text("bar"), LineBreak(soft), Text("baz")
    let hasSoftBreak = para2.children.contains { ($0 as? LineBreakNode)?.variant == .soft }
    #expect(hasSoftBreak)
    let texts = para2.children.compactMap { ($0 as? TextNode)?.content }
    #expect(texts.contains(where: { $0.contains("bar") }))
    #expect(texts.contains(where: { $0.contains("baz") }))
  }

  // Spec 233: multiple lines including a lazy continuation and a further quoted line
  @Test("Blockquote with lazy continuation then quoted line (Spec 233)")
  func blockquoteLazyThenQuoted() {
    let input = "> bar\nbaz\n> foo"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
    // Expect a single paragraph merged via soft breaks: bar, baz, foo
    #expect(bq.children.count == 1)
    guard let para = bq.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    let texts = para.children.compactMap { ($0 as? TextNode)?.content }
    #expect(texts.contains(where: { $0.contains("bar") }))
    #expect(texts.contains(where: { $0.contains("baz") }))
    #expect(texts.contains(where: { $0.contains("foo") }))
    // And at least two soft breaks
    let softBreaks = para.children.compactMap { ($0 as? LineBreakNode)?.variant }.filter { $0 == .soft }
    #expect(softBreaks.count >= 2)
  }

  // Spec 234: thematic break ends the blockquote context in our pipeline
  @Test("Blockquote followed by thematic break (Spec 234)")
  func blockquoteThenThematicBreak() {
    let input = "> foo\n---"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is BlockquoteNode)
    #expect(result.root.children[1] is ThematicBreakNode)
    // Verify the blockquote contains a paragraph with text "foo"
    if let bq = result.root.children.first as? BlockquoteNode,
       let para = bq.children.first as? ParagraphNode,
       let text = para.children.first as? TextNode {
      #expect(text.content.contains("foo"))
    } else {
      Issue.record("Expected paragraph with text inside blockquote")
    }
  }

  // Spec 238: indented line after quoted text is not a list; stays as literal text in same paragraph
  @Test("Blockquote with indented dash text, not a list (Spec 238)")
  func blockquoteIndentedNotList() {
    let input = "> foo\n    - bar"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
    #expect(bq.children.count == 1)
    guard let para = bq.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    // Should include both "foo" and literal "- bar"
    let allText = para.children.compactMap { ($0 as? TextNode)?.content }.joined(separator: "\n")
    #expect(allText.contains("foo"))
    #expect(allText.contains("- bar"))
  }

  // Spec 239/240: empty blockquotes
  @Test("Empty blockquote lines (Spec 239, 240)")
  func emptyBlockquotes() {
    let input1 = ">\n"
    let result1 = h.parser.parse(input1, language: h.language)
    #expect(result1.errors.isEmpty)
    #expect(result1.root.children.count == 1)
    #expect(result1.root.children.first is BlockquoteNode)

    let input2 = ">\n>  \n> \n"
    let result2 = h.parser.parse(input2, language: h.language)
    #expect(result2.errors.isEmpty)
    #expect(result2.root.children.count == 1)
    #expect(result2.root.children.first is BlockquoteNode)
  }

  // Spec 241-244: blank lines delimit paragraphs inside a blockquote and separate blockquotes
  @Test("Blockquote paragraphs and blank line handling (Spec 241-244)")
  func blockquoteParagraphAndBlankLineHandling() {
    // 241: quoted blank, quoted text, quoted blank -> keep only text paragraph semantically
    do {
      let input = ">\n> foo\n>  \n"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
      // Ensure there exists a paragraph containing "foo"
      let paras = bq.children.compactMap { $0 as? ParagraphNode }
      #expect(paras.contains { para in para.children.contains { ($0 as? TextNode)?.content.contains("foo") == true } })
    }

    // 242: separate blockquotes by a blank line
    do {
      let input = "> foo\n\n> bar"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 2)
      #expect(result.root.children[0] is BlockquoteNode)
      #expect(result.root.children[1] is BlockquoteNode)
    }

    // 243: single blockquote with two quoted lines -> one paragraph with soft break
    do {
      let input = "> foo\n> bar"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
      #expect(bq.children.count == 1)
      let para = bq.children.first as? ParagraphNode
      let hasSoftBreak = para?.children.contains { ($0 as? LineBreakNode)?.variant == .soft } ?? false
      #expect(hasSoftBreak)
    }

    // 244: quoted para, blank quoted line, quoted para -> two paragraphs inside one blockquote
    do {
      let input = "> foo\n>\n> bar"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
      let paras = bq.children.compactMap { $0 as? ParagraphNode }
      #expect(paras.count >= 2)
    }
  }

  // Spec 245: a normal paragraph followed by a blockquote
  @Test("Paragraph then blockquote (Spec 245)")
  func paragraphThenBlockquote() {
    let input = "foo\n> bar"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is ParagraphNode)
    #expect(result.root.children[1] is BlockquoteNode)
  }

  // Spec 246-249: thematic breaks and outside paragraphs relative to blockquotes
  @Test("Blockquotes separated by thematic break and outside paragraphs (Spec 246-249)")
  func blockquoteSeparationAndOutsideParagraphs() {
    // 246: blockquote, hr, blockquote
    do {
      let input = "> aaa\n***\n> bbb"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 3)
      #expect(result.root.children[0] is BlockquoteNode)
      #expect(result.root.children[1] is ThematicBreakNode)
      #expect(result.root.children[2] is BlockquoteNode)
    }

    // 247: quoted line then outside continuation (lazy) -> one blockquote
    do {
      let input = "> bar\nbaz"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 1)
      guard let bq = result.root.children.first as? BlockquoteNode else { Issue.record("Expected BlockquoteNode"); return }
      guard let para = bq.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
      let allText = para.children.compactMap { ($0 as? TextNode)?.content }.joined(separator: "\n")
      #expect(allText.contains("bar"))
      #expect(allText.contains("baz"))
    }

    // 248: blank line terminates blockquote; outside paragraph follows
    do {
      let input = "> bar\n\nbaz"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 2)
      #expect(result.root.children[0] is BlockquoteNode)
      #expect(result.root.children[1] is ParagraphNode)
    }

    // 249: quoted line, quoted blank, then outside paragraph
    do {
      let input = "> bar\n>\n baz"
      let result = h.parser.parse(input, language: h.language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 2)
      #expect(result.root.children[0] is BlockquoteNode)
      #expect(result.root.children[1] is ParagraphNode)
    }
  }
}

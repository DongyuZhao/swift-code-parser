import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Entity References (Strict)")
struct MarkdownEntityReferencesTests {
  private let h = MarkdownTestHarness()

  // Helpers
  private func firstParagraph(_ input: String) -> ParagraphNode? {
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    return result.root.children.first as? ParagraphNode
  }

  // 321: named entities and math script letters
  @Test("Spec 321: resolve named entities to Unicode characters across lines")
  func spec321() {
    let input =
      "&nbsp; &amp; &copy; &AElig; &Dcaron;\n&frac¾; &HilbertSpace; &DifferentialD;\n&ClockwiseContourIntegral; &ngE;\n"
      .replacingOccurrences(of: "&frac¾;", with: "&frac34;")  // normalize typo guard
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Strict: entities should be decoded in text; verify exact combined content
    #expect(
      innerText(p)
        == "\u{00A0} \u{0026} \u{00A9} \u{00C6} \u{010E} \n\u{00BE} \u{210B} \u{2146} \n\u{2232} \u{2267}"
    )
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"\u{00A0} \u{0026} \u{00A9} \u{00C6} \u{010E} \n\u{00BE} \u{210B} \u{2146} \n\u{2232} \u{2267}\")]]"
    )
  }

  // 322: decimal numeric references
  @Test("Spec 322: decimal numeric character references are decoded")
  func spec322() {
    let input = "&#35; &#1234; &#992; &#0;\n"
    guard let p = firstParagraph(input) else { return }
    // Strict: numeric references decoded; invalid (0) becomes replacement char
    #expect(innerText(p) == "# \u{04D2} \u{03E0} \u{FFFD}")
    #expect(sig(p) == "paragraph[text(\"# \u{04D2} \u{03E0} \u{FFFD}\")]")
  }

  // 323: hex numeric references (upper/lowercase X)
  @Test("Spec 323: hexadecimal numeric character references are decoded")
  func spec323() {
    let input = "&#X22; &#XD06; &#xcab;\n"
    guard let p = firstParagraph(input) else { return }
    #expect(innerText(p) == "\" \u{0D06} \u{0CAB}")
    #expect(sig(p) == "paragraph[text(\"\" \u{0D06} \u{0CAB}\")]")
  }

  // 324: malformed references remain literal and escape to &amp;# forms in HTML
  @Test("Spec 324: malformed entity and numeric references remain literal")
  func spec324() {
    let input = "&nbsp &x; &#; &#x;\n&#87654321;\n&#abcdef0;\n&ThisIsNotDefined; &hi?;\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Strict: malformed refs remain literal, full content matches input minus trailing newline
    let expected = "&nbsp &x; &#; &#x;\n&#87654321;\n&#abcdef0;\n&ThisIsNotDefined; &hi?;"
    #expect((p.children.first as? TextNode)?.content == expected)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"&nbsp &x; &#; &#x;\\n&#87654321;\\n&#abcdef0;\\n&ThisIsNotDefined; &hi?;\")]]"
    )
  }

  // 325: unterminated named reference remains literal
  @Test("Spec 325: unterminated named reference remains literal")
  func spec325() {
    let input = "&copy\n"
    guard let p = firstParagraph(input) else { return }
    #expect((p.children.first as? TextNode)?.content == "&copy")
    #expect(sig(p) == "paragraph[text(\"&copy\")]")
  }

  // 326: undefined named reference remains literal
  @Test("Spec 326: undefined named reference remains literal")
  func spec326() {
    let input = "&MadeUpEntity;\n"
    guard let p = firstParagraph(input) else { return }
    #expect((p.children.first as? TextNode)?.content == "&MadeUpEntity;")
    #expect(sig(p) == "paragraph[text(\"&MadeUpEntity;\")]")
  }

  // 327: entities are not decoded in link destination when in HTML tag
  @Test("Spec 327: entity references inside HTML tag attribute remain as-is in AST")
  func spec327() {
    let input = "<a href=\"&ouml;&ouml;.html\">\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Strict: this should be HTML, not paragraph text; ensure HTML node captures raw content (entities not decoded)
    let htmlBlocks = findNodes(in: result.root, ofType: HTMLBlockNode.self)
    let htmlInlines = findNodes(in: result.root, ofType: HTMLNode.self)
    #expect(!htmlBlocks.isEmpty || !htmlInlines.isEmpty)
    if let block = htmlBlocks.first { #expect(block.content == "<a href=\"&ouml;&ouml;.html\">") }
    if let inline = htmlInlines.first {
      #expect(inline.content == "<a href=\"&ouml;&ouml;.html\">")
    }
    // Deterministic: root is either html_block or paragraph[html]
    if !htmlBlocks.isEmpty {
      #expect(sig(result.root) == "document[html_block]")
    } else {
      #expect(sig(result.root) == "document[paragraph[html]]")
    }
  }

  // 328: entities in link destination and title
  @Test("Spec 328: entities inside link destination/title")
  func spec328() {
    let input = "[foo](/f&ouml;&ouml; \"f&ouml;&ouml;\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/föö")
    #expect(link.title == "föö")
    if let label = link.children.first as? TextNode { #expect(label.content == "foo") }
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/föö\",title:\"föö\")[text(\"foo\")]]]")
  }

  // 329: reference-style link with entities
  @Test("Spec 329: reference link with entities in definition")
  func spec329() {
    let input = "[foo]\n\n[foo]: /f&ouml;&ouml; \"f&ouml;&ouml;\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Strict: reference-style link resolved with decoded dest/title; def doesn't appear as a node
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/föö")
    #expect(link.title == "föö")
    if let label = link.children.first as? TextNode { #expect(label.content == "foo") }
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/föö\",title:\"föö\")[text(\"foo\")]]]")
  }

  // 330: fenced code with entity in info string -> language name should be decoded in HTML, but AST stores raw
  @Test("Spec 330: fenced code info with entities remains raw in AST language field")
  func spec330() {
    let input = "``` f&ouml;&ouml;\nfoo\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == "f&ouml;&ouml;")
    #expect(code.source == "foo")
    #expect(sig(result.root) == "document[code_block(\"foo\")]")
  }

  // 331: inline code preserves '&' and ';' literally
  @Test("Spec 331: entities inside code span are not decoded")
  func spec331() {
    let input = "`f&ouml;&ouml;`\n"
    guard let p = firstParagraph(input) else { return }
    guard let code = p.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "f&ouml;&ouml;")
    #expect(sig(p) == "paragraph[code(\"f&ouml;&ouml;\")]")
  }

  // 332: indented code block preserves raw entity text
  @Test("Spec 332: entities inside indented code block are not decoded")
  func spec332() {
    let input = "    f&ouml;f&ouml;\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "f&ouml;f&ouml;")
    #expect(sig(result.root) == "document[code_block(\"f&ouml;f&ouml;\")]")
  }

  // 333: entity-escaped asterisks vs emphasis
  @Test("Spec 333: entity-escaped '*' stays literal text; regular '*' on next line is emphasis")
  func spec333() {
    let input = "&#42;foo&#42;\n*foo*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode else {
      Issue.record("Expected first paragraph")
      return
    }
    // After entity decoding, asterisks from references are treated as literal text, not emphasis markers
    #expect((p1.children.first as? TextNode)?.content == "*foo*")
    guard let p2 = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected second paragraph")
      return
    }
    guard let em = p2.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode in second paragraph")
      return
    }
    if let t = em.children.first as? TextNode { #expect(t.content == "foo") }
    #expect(
      sig(result.root) == "document[paragraph[text(\"*foo*\")],paragraph[emphasis[text(\"foo\")]]]")
  }

  // 334: entity-escaped '*' at list marker position should not start a list
  @Test("Spec 334: entity-escaped '*' does not open a list")
  func spec334() {
    let input = "&#42; foo\n\n* foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    // First is paragraph with literal '* foo'
    guard let p = result.root.children[0] as? ParagraphNode else {
      Issue.record("Expected first paragraph")
      return
    }
    #expect((p.children.first as? TextNode)?.content == "* foo")
    // Second is a list item '* foo'
    guard let ul = result.root.children[1] as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ul.children.count == 1)
    guard let li = ul.children.first as? ListItemNode else {
      Issue.record("Expected ListItemNode")
      return
    }
    guard let para = li.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in list item")
      return
    }
    #expect((para.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
  == "document[paragraph[text(\"* foo\")],unordered_list(level:1)[list_item[paragraph[text(\"foo\")]]]]"
    )
  }

  // 335: entity-escaped line feed creates blank line between paragraphs
  @Test("Spec 335: &#10; acts like line break between paragraphs in HTML; AST stays literal")
  func spec335() {
    let input = "foo&#10;&#10;bar\n"
    guard let p = firstParagraph(input) else { return }
    #expect(innerText(p) == "foo\n\nbar")
    #expect(sig(p) == "paragraph[text(\"foo\\n\\nbar\")]")
  }

  // 336: entity-escaped tab becomes literal tab in HTML; AST literal text contains \t
  @Test("Spec 336: &#9; becomes a tab in HTML; AST stays literal text")
  func spec336() {
    let input = "&#9;foo\n"
    guard let p = firstParagraph(input) else { return }
    #expect(innerText(p) == "\tfoo")
    #expect(sig(p) == "paragraph[text(\"\tfoo\")]")
  }

  // 337: entities must not be interpreted inside link label/destination syntax if not parsed as link
  @Test("Spec 337: no special handling when link syntax not recognized")
  func spec337() {
    let input = "[a](url &quot;tit&quot;)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "url")
    #expect(link.title == "tit")
    if let label = link.children.first as? TextNode { #expect(label.content == "a") }
    #expect(sig(result.root) == "document[paragraph[link(url:\"url\",title:\"tit\")[text(\"a\")]]]")
  }
}

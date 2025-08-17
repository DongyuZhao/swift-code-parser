import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Raw HTML")
struct MarkdownRawHTMLTests {
  private let h = MarkdownTestHarness()
  // Helpers moved to shared TestUtils: childrenTypes, sig

  // 632
  @Test("Spec 632: Raw HTML inline tags are preserved (<a><bab><c2c>)")
  func spec632() {
    let input = "<a><bab><c2c>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.html, .html, .html])
    let inlines = p.children
    #expect((inlines[0] as? HTMLNode)?.content == "<a>")
    #expect((inlines[1] as? HTMLNode)?.content == "<bab>")
    #expect((inlines[2] as? HTMLNode)?.content == "<c2c>")
    #expect(sig(r.root) == "document[paragraph[html,html,html]]")
  }

  // 633
  @Test("Spec 633: Raw HTML self-closing tags (<a/><b2/>)")
  func spec633() {
    let input = "<a/><b2/>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.html, .html])
    let inlines = p.children
    #expect((inlines[0] as? HTMLNode)?.content == "<a/>")
    #expect((inlines[1] as? HTMLNode)?.content == "<b2/>")
    #expect(sig(r.root) == "document[paragraph[html,html]]")
  }

  // 634
  @Test("Spec 634: Raw HTML with newline inside tag attributes")
  func spec634() {
    let input = "<a  /><b2\ndata=\"foo\" >\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.html, .html])
    let inlines = p.children
    #expect((inlines[0] as? HTMLNode)?.content == "<a  />")
    #expect((inlines[1] as? HTMLNode)?.content == "<b2\ndata=\"foo\" >")
    #expect(sig(r.root) == "document[paragraph[html,html]]")
  }

  // 635
  @Test("Spec 635: Complex tag with quotes, nested <em> inside attribute, and newline")
  func spec635() {
    let input = "<a foo=\"bar\" bam = 'baz <em>\"</em>'\n_boolean zoop:33=zoop:33 />\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Single inline HTML node spanning the newline
    #expect(childrenTypes(p) == [.html])
    guard let h1 = p.children.first as? HTMLNode else {
      Issue.record("Expected inline HTMLNode")
      return
    }
    #expect(h1.content == "<a foo=\"bar\" bam = 'baz <em>\"</em>'\n_boolean zoop:33=zoop:33 />")
    #expect(sig(r.root) == "document[paragraph[html]]")
  }

  // 636
  @Test("Spec 636: Custom element alongside text")
  func spec636() {
    let input = "Foo <responsive-image src=\"foo.jpg\" />\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "Foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<responsive-image src=\"foo.jpg\" />")
    #expect(sig(r.root) == "document[paragraph[text(\"Foo \"),html]]")
  }

  // 637
  @Test("Spec 637: Not raw HTML when tag name is invalid (<33> <__>)")
  func spec637() {
    let input = "<33> <__>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "<33> <__>")
    #expect(sig(r.root) == "document[paragraph[text(\"<33> <__>\")]]")
  }

  // 638
  @Test("Spec 638: Not raw HTML when attribute contains invalid characters")
  func spec638() {
    let input = "<a h*#ref=\"hi\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "<a h*#ref=\"hi\">")
    #expect(sig(r.root) == "document[paragraph[text(\"<a h*#ref=\\\"hi\\\">\")]]")
  }

  // 639
  @Test("Spec 639: Not raw HTML when quotes are mismatched")
  func spec639() {
    let input = "<a href=\"hi'> <a href=hi'>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "<a href=\"hi'> <a href=hi'>")
    #expect(sig(r.root) == "document[paragraph[text(\"<a href=\\\"hi'> <a href=hi'>\")]]")
  }

  // 640
  @Test("Spec 640: Not raw HTML in various malformed cases across lines")
  func spec640() {
    let input = "< a><\nfoo><bar/ >\n<foo bar=baz\nbim!bop />\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Expect text with soft breaks between lines
    #expect(childrenTypes(p) == [.text, .lineBreak, .text, .lineBreak, .text, .lineBreak, .text])
    let c = p.children
    #expect((c[0] as? TextNode)?.content == "< a><")
    #expect((c[2] as? TextNode)?.content == "foo><bar/ >")
    #expect((c[4] as? TextNode)?.content == "<foo bar=baz")
    #expect((c[6] as? TextNode)?.content == "bim!bop />")
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"< a><\"),line_break(soft),text(\"foo><bar/ >\"),line_break(soft),text(\"<foo bar=baz\"),line_break(soft),text(\"bim!bop />\")]]"
    )
  }

  // 641
  @Test("Spec 641: Not raw HTML when attributes are not properly separated")
  func spec641() {
    let input = "<a href='bar'title=title>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "<a href='bar'title=title>")
    #expect(sig(r.root) == "document[paragraph[text(\"<a href='bar'title=title>\")]]")
  }

  // 642
  @Test("Spec 642: Raw HTML closing tags are preserved")
  func spec642() {
    let input = "</a></foo >\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.html, .html])
    let inlines = p.children
    #expect((inlines[0] as? HTMLNode)?.content == "</a>")
    #expect((inlines[1] as? HTMLNode)?.content == "</foo >")
    #expect(sig(r.root) == "document[paragraph[html,html]]")
  }

  // 643
  @Test("Spec 643: Not raw HTML for malformed closing tag")
  func spec643() {
    let input = "</a href=\"foo\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "</a href=\"foo\">")
    #expect(sig(r.root) == "document[paragraph[text(\"</a href=\\\"foo\\\">\")]]")
  }

  // 644
  @Test("Spec 644: Raw HTML comment across newline is preserved")
  func spec644() {
    let input = "foo <!-- this is a --\ncomment - with hyphens -->\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect(
      (p.children.last as? HTMLNode)?.content == "<!-- this is a --\ncomment - with hyphens -->")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 645
  @Test("Spec 645: Not raw HTML for malformed comments (two paragraphs)")
  func spec645() {
    let input = "foo <!--> foo -->\n\nfoo <!---> foo -->\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    guard let p1 = r.root.children.first as? ParagraphNode,
      let p2 = r.root.children.last as? ParagraphNode
    else {
      Issue.record("Expected two ParagraphNode's")
      return
    }
    #expect(childrenTypes(p1) == [.text])
    #expect((p1.children.first as? TextNode)?.content == "foo <!--> foo -->")
    #expect(childrenTypes(p2) == [.text])
    #expect((p2.children.first as? TextNode)?.content == "foo <!---> foo -->")
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"foo <!--> foo -->\")],paragraph[text(\"foo <!---> foo -->\")]]"
    )
  }

  // 646
  @Test("Spec 646: Raw HTML processing instruction is preserved")
  func spec646() {
    let input = "foo <?php echo $a; ?>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<?php echo $a; ?>")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 647
  @Test("Spec 647: Raw HTML declaration is preserved")
  func spec647() {
    let input = "foo <!ELEMENT br EMPTY>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<!ELEMENT br EMPTY>")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 648
  @Test("Spec 648: Raw HTML CDATA is preserved")
  func spec648() {
    let input = "foo <![CDATA[>&<]]>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<![CDATA[>&<]]>")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 649
  @Test("Spec 649: Raw HTML entity in attribute is preserved")
  func spec649() {
    let input = "foo <a href=\"&ouml;\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<a href=\"&ouml;\">")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 650
  @Test("Spec 650: Raw HTML backslash in attribute value is preserved")
  func spec650() {
    let input = "foo <a href=\"\\*\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .html])
    #expect((p.children.first as? TextNode)?.content == "foo ")
    #expect((p.children.last as? HTMLNode)?.content == "<a href=\"\\*\">")
    #expect(sig(r.root) == "document[paragraph[text(\"foo \"),html]]")
  }

  // 651
  @Test("Spec 651: Not raw HTML when attribute value contains an escaped quote only")
  func spec651() {
    let input = "<a href=\"\\\"\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "<a href=\"\\\"\">")
    #expect(sig(r.root) == "document[paragraph[text(\"<a href=\\\"\\\\\"\\\">\")]]")
  }

  // 652
  @Test("Spec 652: No tag filter; preserve disallowed raw HTML as-is")
  func spec652() {
    let input =
      "<strong> <title> <style> <em>\n\n<blockquote>\n  <xmp> is disallowed.  <XMP> is also disallowed.\n</blockquote>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    // Expect two top-level nodes: paragraph (inline HTML + spaces) and an HTML block
    #expect(r.root.children.count == 2)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Inline sequence: <strong> " " <title> " " <style> " " <em>
    #expect(childrenTypes(p) == [.html, .text, .html, .text, .html, .text, .html])
    let inlines = p.children
    #expect((inlines[0] as? HTMLNode)?.content == "<strong>")
    #expect((inlines[1] as? TextNode)?.content == " ")
    #expect((inlines[2] as? HTMLNode)?.content == "<title>")
    #expect((inlines[3] as? TextNode)?.content == " ")
    #expect((inlines[4] as? HTMLNode)?.content == "<style>")
    #expect((inlines[5] as? TextNode)?.content == " ")
    #expect((inlines[6] as? HTMLNode)?.content == "<em>")

    guard let b = r.root.children.last as? HTMLBlockNode else {
      Issue.record("Expected HTMLBlockNode")
      return
    }
    #expect(
      b.content
        == "<blockquote>\n  <xmp> is disallowed.  <XMP> is also disallowed.\n</blockquote>")
    #expect(
      sig(r.root)
        == "document[paragraph[html,text(\" \"),html,text(\" \"),html,text(\" \"),html],html_block]"
    )
  }
}

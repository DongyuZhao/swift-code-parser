import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("GFM - Autolinks (includes GFM extensions)")
struct MarkdownAutolinksTests {
  private let h = MarkdownTestHarness()

  // Helpers moved to Tests/.../Utils/TestUtils.swift

  // 602
  @Test("Spec 602: Simple URI autolink")
  func spec602() {
    let input = "<http://foo.bar.baz>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "http://foo.bar.baz")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "http://foo.bar.baz")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"http://foo.bar.baz\",title:\"\")[text(\"http://foo.bar.baz\")]]]"
    )
  }

  // 603
  @Test("Spec 603: Autolink with query and ampersands")
  func spec603() {
    let input = "<https://foo.bar.baz/test?q=hello&id=22&boolean>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://foo.bar.baz/test?q=hello&id=22&boolean")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "https://foo.bar.baz/test?q=hello&id=22&boolean")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"https://foo.bar.baz/test?q=hello&id=22&boolean\",title:\"\")[text(\"https://foo.bar.baz/test?q=hello&id=22&boolean\")]]]"
    )
  }

  // 604
  @Test("Spec 604: Autolink with non-http scheme and port")
  func spec604() {
    let input = "<irc://foo.bar:2233/baz>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "irc://foo.bar:2233/baz")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "irc://foo.bar:2233/baz")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"irc://foo.bar:2233/baz\",title:\"\")[text(\"irc://foo.bar:2233/baz\")]]]"
    )
  }

  // 605
  @Test("Spec 605: Uppercase MAILTO scheme is valid URI autolink")
  func spec605() {
    let input = "<MAILTO:FOO@BAR.BAZ>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "MAILTO:FOO@BAR.BAZ")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "MAILTO:FOO@BAR.BAZ")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"MAILTO:FOO@BAR.BAZ\",title:\"\")[text(\"MAILTO:FOO@BAR.BAZ\")]]]"
    )
  }

  // 606
  @Test("Spec 606: Autolink with plus signs in scheme")
  func spec606() {
    let input = "<a+b+c:d>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "a+b+c:d")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "a+b+c:d")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"a+b+c:d\",title:\"\")[text(\"a+b+c:d\")]]]"
    )
  }

  // 607
  @Test("Spec 607: Autolink made-up scheme with comma in path")
  func spec607() {
    let input = "<made-up-scheme://foo,bar>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "made-up-scheme://foo,bar")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "made-up-scheme://foo,bar")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"made-up-scheme://foo,bar\",title:\"\")[text(\"made-up-scheme://foo,bar\")]]]"
    )
  }

  // 608
  @Test("Spec 608: Autolink with https and relative dotdot")
  func spec608() {
    let input = "<https://../>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://../")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "https://../")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"https://../\",title:\"\")[text(\"https://../\")]]]")
  }

  // 609
  @Test("Spec 609: Autolink with alpha-only scheme 'localhost'")
  func spec609() {
    let input = "<localhost:5001/foo>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "localhost:5001/foo")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "localhost:5001/foo")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"localhost:5001/foo\",title:\"\")[text(\"localhost:5001/foo\")]]]"
    )
  }

  // 610
  @Test("Spec 610: Not an autolink when space inside angle brackets")
  func spec610() {
    let input = "<https://foo.bar/baz bim>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "<https://foo.bar/baz bim>")
    #expect(sig(result.root) == "document[paragraph[text(\"<https://foo.bar/baz bim>\")]]")
  }

  // 611
  @Test("Spec 611: Backslash escapes do not work inside autolinks (still autolink)")
  func spec611() {
    // Markdown: <https://example.com/\[\>
    let input = "<https://example.com/\\[\\>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://example.com/%5C%5B%5C")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "https://example.com/\\[\\")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"https://example.com/%5C%5B%5C\",title:\"\")[text(\"https://example.com/\\[\\\")]]]"
    )
  }

  // 612
  @Test("Spec 612: Email autolink basic")
  func spec612() {
    let input = "<foo@bar.example.com>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "mailto:foo@bar.example.com")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "foo@bar.example.com")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"mailto:foo@bar.example.com\",title:\"\")[text(\"foo@bar.example.com\")]]]"
    )
  }

  // 613
  @Test("Spec 613: Email autolink with plus and hyphen and digits")
  func spec613() {
    let input = "<foo+special@Bar.baz-bar0.com>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "mailto:foo+special@Bar.baz-bar0.com")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "foo+special@Bar.baz-bar0.com")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"mailto:foo+special@Bar.baz-bar0.com\",title:\"\")[text(\"foo+special@Bar.baz-bar0.com\")]]]"
    )
  }

  // 614
  @Test("Spec 614: Backslash escapes do not work inside email autolinks (not autolink)")
  func spec614() {
    // Markdown: <foo\+@bar.example.com>
    let input = "<foo\\+@bar.example.com>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "<foo\\+@bar.example.com>")
    #expect(sig(result.root) == "document[paragraph[text(\"<foo\\+@bar.example.com>\")]]")
  }

  // 615
  @Test("Spec 615: Not an autolink for empty angle brackets")
  func spec615() {
    let input = "<>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "<>")
    #expect(sig(result.root) == "document[paragraph[text(\"<>\")]]")
  }

  // 616
  @Test("Spec 616: Not an autolink when spaces inside angle brackets")
  func spec616() {
    let input = "< https://foo.bar >\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "< https://foo.bar >")
    #expect(sig(result.root) == "document[paragraph[text(\"< https://foo.bar >\")]]")
  }

  // 617
  @Test("Spec 617: Not an autolink for single-letter scheme")
  func spec617() {
    let input = "<m:abc>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "<m:abc>")
    #expect(sig(result.root) == "document[paragraph[text(\"<m:abc>\")]]")
  }

  // 618
  @Test("Spec 618: Not an autolink for domain-like without scheme")
  func spec618() {
    let input = "<foo.bar.baz>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    guard let t = p.children.first as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(t.content == "<foo.bar.baz>")
    #expect(sig(result.root) == "document[paragraph[text(\"<foo.bar.baz>\")]]")
  }

  // 619
  @Test("Spec 619: Bare domain name without subdomain is not an autolink")
  func spec619() {
    let input = "https://example.com\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://example.com")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "https://example.com")
    #expect(sig(result.root) == "document[paragraph[link(url:\"https://example.com\",title:\"\")[text(\"https://example.com\")]]]")
  }

  // 620
  @Test("Spec 620: Bare email autolinks")
  func spec620() {
    let input = "foo@bar.example.com\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "mailto:foo@bar.example.com")
    #expect(link.title.isEmpty)
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "foo@bar.example.com")
    #expect(sig(result.root) == "document[paragraph[link(url:\"mailto:foo@bar.example.com\",title:\"\")[text(\"foo@bar.example.com\")]]]")
  }

  // 621
  @Test("Spec 621: Bare www autolink")
  func spec621() {
    let input = "www.commonmark.org\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let link = p.children.first as? LinkNode
    else {
      Issue.record("Expected Paragraph with LinkNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    #expect(link.url == "http://www.commonmark.org")
    #expect(link.title.isEmpty)
    #expect((link.children.first as? TextNode)?.content == "www.commonmark.org")
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://www.commonmark.org\",title:\"\")[text(\"www.commonmark.org\")]]]"
    )
  }

  // 622
  @Test("Spec 622: Bare www URL in sentence autolinks")
  func spec622() {
    let input = "Visit www.commonmark.org/help for more information.\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .link, .text])
    guard let t1 = p.children.first as? TextNode,
      let link = p.children.dropFirst().first as? LinkNode,
      let t2 = p.children.last as? TextNode
    else {
      Issue.record("Unexpected inline sequence")
      return
    }
    #expect(t1.content == "Visit ")
    #expect(link.url == "http://www.commonmark.org/help")
    #expect(link.title.isEmpty)
    #expect((link.children.first as? TextNode)?.content == "www.commonmark.org/help")
    #expect(t2.content == " for more information.")
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org/help\",title:\"\")[text(\"www.commonmark.org/help\")],text(\" for more information.\")]]"
    )
  }

  // 623
  @Test("Spec 623: Two paragraphs with bare www URLs autolink with trailing dot outside")
  func spec623() {
    let input = "Visit www.commonmark.org.\n\nVisit www.commonmark.org/a.b.\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    guard let p1 = r.root.children.first as? ParagraphNode,
      let p2 = r.root.children.last as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    // p1: "Visit ", link(www.commonmark.org), "."
    #expect(childrenTypes(p1) == [.text, .link, .text])
    if let tA = p1.children.first as? TextNode,
      let lA = p1.children.dropFirst().first as? LinkNode,
      let tB = p1.children.last as? TextNode
    {
      #expect(tA.content == "Visit ")
      #expect(lA.url == "http://www.commonmark.org")
      #expect((lA.children.first as? TextNode)?.content == "www.commonmark.org")
      #expect(tB.content == ".")
    }
    // p2: "Visit ", link(www.commonmark.org/a.b), "."
    #expect(childrenTypes(p2) == [.text, .link, .text])
    if let tC = p2.children.first as? TextNode,
      let lB = p2.children.dropFirst().first as? LinkNode,
      let tD = p2.children.last as? TextNode
    {
      #expect(tC.content == "Visit ")
      #expect(lB.url == "http://www.commonmark.org/a.b")
      #expect((lB.children.first as? TextNode)?.content == "www.commonmark.org/a.b")
      #expect(tD.content == ".")
    }
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org\",title:\"\")[text(\"www.commonmark.org\")],text(\".\")],paragraph[text(\"Visit \"),link(url:\"http://www.commonmark.org/a.b\",title:\"\")[text(\"www.commonmark.org/a.b\")],text(\".\")]]"
    )
  }

  // 624
  @Test("Spec 624: Bare www with parentheses autolinks; punctuation outside where appropriate")
  func spec624() {
    let input =
      "www.google.com/search?q=Markup+(business)\n\nwww.google.com/search?q=Markup+(business))\n\n(www.google.com/search?q=Markup+(business))\n\n(www.google.com/search?q=Markup+(business)\n"
    // Above forms four paragraphs: 1) link, 2) link+"))", 3) "("+link+")" same line, 4) "("+link same line
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 4)
    // P1: link only
    if let p1 = r.root.children[0] as? ParagraphNode {
      #expect(childrenTypes(p1) == [.link])
      if let l = p1.children.first as? LinkNode {
        #expect(l.url == "http://www.google.com/search?q=Markup+(business)")
        #expect(
          (l.children.first as? TextNode)?.content == "www.google.com/search?q=Markup+(business)")
      }
    }
    // P2: link then ")"
    if let p2 = r.root.children[1] as? ParagraphNode {
      #expect(childrenTypes(p2) == [.link, .text])
      if let l = p2.children.first as? LinkNode, let t = p2.children.last as? TextNode {
        #expect(l.url == "http://www.google.com/search?q=Markup+(business)")
        #expect(
          (l.children.first as? TextNode)?.content == "www.google.com/search?q=Markup+(business)")
        #expect(t.content == ")")
      }
    }
    // P3: "(" then link then ")"
    if let p3 = r.root.children[2] as? ParagraphNode {
      #expect(childrenTypes(p3) == [.text, .link, .text])
      if let t1 = p3.children.first as? TextNode,
        let l = p3.children.dropFirst().first as? LinkNode,
        let t2 = p3.children.last as? TextNode
      {
        #expect(t1.content == "(")
        #expect(l.url == "http://www.google.com/search?q=Markup+(business)")
        #expect(
          (l.children.first as? TextNode)?.content == "www.google.com/search?q=Markup+(business)")
        #expect(t2.content == ")")
      }
    }
    // P4: "(" then link
    if let p4 = r.root.children[3] as? ParagraphNode {
      #expect(childrenTypes(p4) == [.text, .link])
      if let t = p4.children.first as? TextNode, let l = p4.children.last as? LinkNode {
        #expect(t.content == "(")
        #expect(l.url == "http://www.google.com/search?q=Markup+(business)")
        #expect(
          (l.children.first as? TextNode)?.content == "www.google.com/search?q=Markup+(business)")
      }
    }
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")]],paragraph[link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")],text(\")\")],paragraph[text(\"(\"),link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")],text(\")\")],paragraph[text(\"(\"),link(url:\"http://www.google.com/search?q=Markup+(business)\",title:\"\")[text(\"www.google.com/search?q=Markup+(business)\")]]]"
    )
  }

  // 625
  @Test("Spec 625: Bare www with complex query autolinks")
  func spec625() {
    let input = "www.google.com/search?q=(business))+ok\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let l = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    #expect(l.url == "http://www.google.com/search?q=(business))+ok")
    #expect((l.children.first as? TextNode)?.content == "www.google.com/search?q=(business))+ok")
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://www.google.com/search?q=(business))+ok\",title:\"\")[text(\"www.google.com/search?q=(business))+ok\")]]]"
    )
  }

  // 626
  @Test("Spec 626: Bare www with ampersands autolinks; entity-like tail outside link")
  func spec626() {
    let input =
      "www.google.com/search?q=commonmark&hl=en\n\nwww.google.com/search?q=commonmark&hl;\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 2)
    // P1
    if let p1 = r.root.children.first as? ParagraphNode, let l1 = p1.children.first as? LinkNode {
      #expect(childrenTypes(p1) == [.link])
      #expect(l1.url == "http://www.google.com/search?q=commonmark&hl=en")
      #expect(
        (l1.children.first as? TextNode)?.content == "www.google.com/search?q=commonmark&hl=en")
    }
    // P2
    if let p2 = r.root.children.last as? ParagraphNode {
      #expect(childrenTypes(p2) == [.link, .text])
      if let l2 = p2.children.first as? LinkNode, let t = p2.children.last as? TextNode {
        #expect(l2.url == "http://www.google.com/search?q=commonmark")
        #expect((l2.children.first as? TextNode)?.content == "www.google.com/search?q=commonmark")
        #expect(t.content == "&hl;")
      }
    }
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://www.google.com/search?q=commonmark&hl=en\",title:\"\")[text(\"www.google.com/search?q=commonmark&hl=en\")]],paragraph[link(url:\"http://www.google.com/search?q=commonmark\",title:\"\")[text(\"www.google.com/search?q=commonmark\")],text(\"&hl;\")]]"
    )
  }

  // 627
  @Test("Spec 627: Bare www interrupted by <")
  func spec627() {
    let input = "www.commonmark.org/he<lp\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link, .text])
    if let l = p.children.first as? LinkNode, let t = p.children.last as? TextNode {
      #expect(l.url == "http://www.commonmark.org/he")
      #expect((l.children.first as? TextNode)?.content == "www.commonmark.org/he")
      #expect(t.content == "<lp")
    }
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://www.commonmark.org/he\",title:\"\")[text(\"www.commonmark.org/he\")],text(\"<lp\")]]"
    )
  }

  // 628
  @Test("Spec 628: Mixed bare URLs autolink (http/https/ftp) in multiple paragraphs")
  func spec628() {
    let input =
      "http://commonmark.org\n\n(Visit https://encrypted.google.com/search?q=Markup+(business))\n\nAnonymous FTP is available at ftp://foo.bar.baz.\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 3)
    // P1
    if let p1 = r.root.children[0] as? ParagraphNode, let l1 = p1.children.first as? LinkNode {
      #expect(childrenTypes(p1) == [.link])
      #expect(l1.url == "http://commonmark.org")
      #expect((l1.children.first as? TextNode)?.content == "http://commonmark.org")
    }
    // P2
    if let p2 = r.root.children[1] as? ParagraphNode {
      #expect(childrenTypes(p2) == [.text, .link, .text])
      if let t1 = p2.children.first as? TextNode,
        let l2 = p2.children.dropFirst().first as? LinkNode,
        let t2 = p2.children.last as? TextNode
      {
        #expect(t1.content == "(Visit ")
        #expect(l2.url == "https://encrypted.google.com/search?q=Markup+(business)")
        #expect(
          (l2.children.first as? TextNode)?.content
            == "https://encrypted.google.com/search?q=Markup+(business)")
        #expect(t2.content == ")")
      }
    }
    // P3
    if let p3 = r.root.children[2] as? ParagraphNode {
      #expect(childrenTypes(p3) == [.text, .link, .text])
      if let t1 = p3.children.first as? TextNode,
        let l3 = p3.children.dropFirst().first as? LinkNode,
        let t2 = p3.children.last as? TextNode
      {
        #expect(t1.content == "Anonymous FTP is available at ")
        #expect(l3.url == "ftp://foo.bar.baz")
        #expect((l3.children.first as? TextNode)?.content == "ftp://foo.bar.baz")
        #expect(t2.content == ".")
      }
    }
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"http://commonmark.org\",title:\"\")[text(\"http://commonmark.org\")]],paragraph[text(\"(Visit \"),link(url:\"https://encrypted.google.com/search?q=Markup+(business)\",title:\"\")[text(\"https://encrypted.google.com/search?q=Markup+(business)\")],text(\")\")],paragraph[text(\"Anonymous FTP is available at \"),link(url:\"ftp://foo.bar.baz\",title:\"\")[text(\"ftp://foo.bar.baz\")],text(\".\")]]"
    )
  }

  // 629
  @Test("Spec 629: Bare email autolinks")
  func spec629() {
    let input = "foo@bar.baz\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let l = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
    #expect(l.url == "mailto:foo@bar.baz")
    #expect((l.children.first as? TextNode)?.content == "foo@bar.baz")
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"mailto:foo@bar.baz\",title:\"\")[text(\"foo@bar.baz\")]]]"
    )
  }

  // 630
  @Test("Spec 630: Only second email autolinks in sentence")
  func spec630() {
    let input = "hello@mail+xyz.example isn't valid, but hello+xyz@mail.example is.\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .link, .text])
    if let t1 = p.children.first as? TextNode,
      let l = p.children.dropFirst().first as? LinkNode,
      let t2 = p.children.last as? TextNode
    {
      #expect(t1.content == "hello@mail+xyz.example isn't valid, but ")
      #expect(l.url == "mailto:hello+xyz@mail.example")
      #expect((l.children.first as? TextNode)?.content == "hello+xyz@mail.example")
      #expect(t2.content == " is.")
    }
    #expect(
      sig(r.root)
        == "document[paragraph[text(\"hello@mail+xyz.example isn't valid, but \"),link(url:\"mailto:hello+xyz@mail.example\",title:\"\")[text(\"hello+xyz@mail.example\")],text(\" is.\")]]"
    )
  }

  // 631
  @Test("Spec 631: Email-like variants; only valid forms autolink")
  func spec631() {
    let input = "a.b-c_d@a.b\n\na.b-c_d@a.b.\n\na.b-c_d@a.b-\n\na.b-c_d@a.b_\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(r.root.children.count == 4)
    // P1: link only
    if let p1 = r.root.children[0] as? ParagraphNode, let l1 = p1.children.first as? LinkNode {
      #expect(childrenTypes(p1) == [.link])
      #expect(l1.url == "mailto:a.b-c_d@a.b")
      #expect((l1.children.first as? TextNode)?.content == "a.b-c_d@a.b")
    }
    // P2: link then trailing period
    if let p2 = r.root.children[1] as? ParagraphNode {
      #expect(childrenTypes(p2) == [.link, .text])
      if let l2 = p2.children.first as? LinkNode, let t = p2.children.last as? TextNode {
        #expect(l2.url == "mailto:a.b-c_d@a.b")
        #expect((l2.children.first as? TextNode)?.content == "a.b-c_d@a.b")
        #expect(t.content == ".")
      }
    }
    // P3: invalid -> plain text
    if let p3 = r.root.children[2] as? ParagraphNode, let t3 = p3.children.first as? TextNode {
      #expect(childrenTypes(p3) == [.text])
      #expect(t3.content == "a.b-c_d@a.b-")
    }
    // P4: invalid -> plain text
    if let p4 = r.root.children[3] as? ParagraphNode, let t4 = p4.children.first as? TextNode {
      #expect(childrenTypes(p4) == [.text])
      #expect(t4.content == "a.b-c_d@a.b_")
    }
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"mailto:a.b-c_d@a.b\",title:\"\")[text(\"a.b-c_d@a.b\")]],paragraph[link(url:\"mailto:a.b-c_d@a.b\",title:\"\")[text(\"a.b-c_d@a.b\")],text(\".\")],paragraph[text(\"a.b-c_d@a.b-\")],paragraph[text(\"a.b-c_d@a.b_\")]]"
    )
  }
}

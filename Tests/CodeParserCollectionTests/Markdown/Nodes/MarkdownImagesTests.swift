import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Images (Strict)")
struct MarkdownImagesTests {
  private let h = MarkdownTestHarness()

  // 580
  @Test("Spec 580: Inline image with title")
  func spec580() {
    let input = "![foo](/url \"title\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.image])
    guard let img = p.children.first as? ImageNode else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")]]")
  }

  // 581
  @Test("Spec 581: Inline image without title")
  func spec581() {
    let input = "![foo](/url)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.image])
    guard let img = p.children.first as? ImageNode else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title.isEmpty)
    #expect(img.alt == "foo")
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"\")]]")
  }

  // 582
  @Test("Spec 582: Inline image with empty alt")
  func spec582() {
    let input = "![](/url)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let img = p.children.first as? ImageNode else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.alt.isEmpty)
    #expect(img.url == "/url")
    #expect(img.title.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"\",title:\"\")]]")
  }

  // 583
  @Test("Spec 583: Angle-bracketed destination encodes spaces")
  func spec583() {
    let input = "![foo](</my url>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let img = p.children.first as? ImageNode else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "my%20url")
    #expect(img.title.isEmpty)
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"my%20url\",alt:\"foo\",title:\"\")]]")
  }

  // 584
  @Test("Spec 584: Escapes in destination and title normalized")
  func spec584() {
    let input = "![foo](/url\\* \"ti\\*tle\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url*")
    #expect(img.title == "ti*tle")
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url*\",alt:\"foo\",title:\"ti*tle\")]]")
  }

  // 585
  @Test("Spec 585: Full reference image")
  func spec585() {
    let input = "![foo][bar]\n\n[bar]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")]]")
  }

  // 586
  @Test("Spec 586: Collapsed reference image")
  func spec586() {
    let input = "![foo][]\n\n[foo]: /url 'title'\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")]]")
  }

  // 587
  @Test("Spec 587: Shortcut reference image")
  func spec587() {
    let input = "![foo]\n\n[foo]: /url\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title.isEmpty)
    #expect(img.alt == "foo")
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"\")]]")
  }

  // 588
  @Test("Spec 588: Reference label matching is case-insensitive")
  func spec588() {
    let input = "![Foo]\n\n[FOO]: /url \"T\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "T")
    #expect(img.alt == "Foo")
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"T\")]]")
  }

  // 589
  @Test("Spec 589: Image inside link")
  func spec589() {
    let input = "[![moon](/moon.jpg)](/target)\n"
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
    #expect(link.url == "/target")
    #expect(link.title.isEmpty)
    guard let img = link.children.first as? ImageNode else {
      Issue.record("Expected inner ImageNode")
      return
    }
    #expect(img.url == "/moon.jpg")
    #expect(img.title.isEmpty)
    #expect(img.alt == "moon")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/target\",title:\"\")[image(url:\"/moon.jpg\",alt:\"moon\",title:\"\")]]]"
    )
  }

  // 590
  @Test("Spec 590: Image inside emphasis")
  func spec590() {
    let input = "*![foo](/url)*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.emphasis])
    guard let em = p.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(childrenTypes(em) == [.image])
    guard let img = em.children.first as? ImageNode else {
      Issue.record("Expected ImageNode inside emphasis")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title.isEmpty)
    #expect(img.alt == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[emphasis[image(url:\"/url\",alt:\"foo\",title:\"\")]]]")
  }

  // 591
  @Test("Spec 591: Image surrounded by text segments")
  func spec591() {
    let input = "A ![alt](/u) B\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .image, .text])
    guard let t1 = p.children.first as? TextNode,
      let img = p.children.dropFirst().first as? ImageNode,
      let t2 = p.children.last as? TextNode
    else {
      Issue.record("Expected [Text, Image, Text]")
      return
    }
    #expect(t1.content == "A ")
    #expect(img.url == "/u")
    #expect(img.alt == "alt")
    #expect(t2.content == " B")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"A \"),image(url:\"/u\",alt:\"alt\",title:\"\"),text(\" B\")]]"
    )
  }

  // 592
  @Test("Spec 592: Collapsed reference image with inline content in label")
  func spec592() {
    let input = "![*foo* bar][]\n\n[*foo* bar]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo bar")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo bar\",title:\"title\")]]"
    )
  }

  // 593
  @Test("Spec 593: Collapsed reference label matching is case-insensitive")
  func spec593() {
    let input = "![Foo][]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "Foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"title\")]]")
  }

  // 594
  @Test("Spec 594: No spaces/newlines allowed between label and [] for collapsed form")
  func spec594() {
    let input = "![foo]  \n[]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected first paragraph")
      return
    }
    // Expect image resolved via shortcut, followed by literal [] on next line (soft break + text)
    #expect(childrenTypes(p) == [.image, .lineBreak, .text])
    guard let img = p.children.first as? ImageNode else {
      Issue.record("Expected first child ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo")
    guard let t = p.children.last as? TextNode else {
      Issue.record("Expected trailing TextNode")
      return
    }
    #expect(t.content == "[]")
    #expect(
      sig(result.root)
        == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\"),line_break(soft),text(\"[]\")]]"
    )
  }

  // 595
  @Test("Spec 595: Shortcut reference image")
  func spec595() {
    let input = "![foo]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")]]")
  }

  // 596
  @Test("Spec 596: Shortcut reference image with inline content in label")
  func spec596() {
    let input = "![*foo* bar]\n\n[*foo* bar]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "foo bar")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo bar\",title:\"title\")]]"
    )
  }

  // 597
  @Test("Spec 597: Link labels in image references cannot contain unescaped brackets")
  func spec597() {
    let input = "![[foo]]\n\n[[foo]]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: ImageNode.self).isEmpty)
    // Both lines render as paragraphs of literal text
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children.first as? ParagraphNode,
      let p2 = result.root.children.last as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    #expect(childrenTypes(p1) == [.text])
    #expect(childrenTypes(p2) == [.text])
    #expect((p1.children.first as? TextNode)?.content == "![[foo]]")
    #expect((p2.children.first as? TextNode)?.content == "[[foo]]: /url \"title\"")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"![[foo]]\")],paragraph[text(\"[[foo]]: /url \\\"title\\\"\")]]"
    )
  }

  // 598
  @Test("Spec 598: Shortcut reference image label matching is case-insensitive")
  func spec598() {
    let input = "![Foo]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "Foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"title\")]]")
  }

  // 599
  @Test("Spec 599: Reference image resolves with capitalized alt")
  func spec599() {
    let input = "![Foo]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let img = findNodes(in: result.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "/url")
    #expect(img.title == "title")
    #expect(img.alt == "Foo")
    #expect(
      sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"title\")]]")
  }

  // 600
  @Test("Spec 600: Escaped bracket after ! yields literal text, not image")
  func spec600() {
    let input = "!\\[foo]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Should be a single paragraph with literal text "![foo]"; the definition is consumed and not rendered
    #expect(findNodes(in: result.root, ofType: ImageNode.self).isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect((p.children.first as? TextNode)?.content == "![foo]")
    #expect(sig(result.root) == "document[paragraph[text(\"![foo]\")]]")
  }

  // 601
  @Test("Spec 601: Escaped ! before label yields literal ! followed by link (not image)")
  func spec601() {
    let input = "\\![foo]\n\n[foo]: /url \"title\"\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect paragraph children: text("!") then link
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph")
      return
    }
    #expect(childrenTypes(p) == [.text, .link])
    guard let t = p.children.first as? TextNode, let link = p.children.last as? LinkNode else {
      Issue.record("Expected Text + Link")
      return
    }
    #expect(t.content == "!")
    #expect(link.url == "/url")
    #expect(link.title == "title")
    guard let lt = link.children.first as? TextNode else {
      Issue.record("Expected link text node")
      return
    }
    #expect(lt.content == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"!\"),link(url:\"/url\",title:\"title\")[text(\"foo\")]]]")
  }
}

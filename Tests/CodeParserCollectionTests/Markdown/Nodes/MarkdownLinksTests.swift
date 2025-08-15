import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Links (Strict)")
struct MarkdownLinksTests {
  private let h = MarkdownTestHarness()
  // childrenTypes/sig moved to shared TestUtils

  // Helpers
  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined(separator: "\n")
  }

  // 493
  @Test("Spec 493: [link](/uri \"title\")")
  func spec493() {
    let input = "[link](/uri \"title\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "/uri")
    #expect(a.title == "title")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"title\")[text(\"link\")]]]")
  }

  // 494
  @Test("Spec 494: [link](/uri)")
  func spec494() {
    let input = "[link](/uri)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "/uri")
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link\")]]]")
  }

  // L1
  @Test("Spec L1: [](./target.md)")
  func specL1() {
    let input = "[](./target.md)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "./target.md")
    #expect(a.title.isEmpty)
    #expect(a.children.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"./target.md\",title:\"\")]]")
  }

  // 495
  @Test("Spec 495: [link]()")
  func spec495() {
    let input = "[link]()\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "")
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"link\")]]]")
  }

  // 496
  @Test("Spec 496: [link](<>)")
  func spec496() {
    let input = "[link](<>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "")
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"link\")]]]")
  }

  // L2
  @Test("Spec L2: []()")
  func specL2() {
    let input = "[]()\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "")
    #expect(a.title.isEmpty)
    #expect(a.children.isEmpty)
    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")]]")
  }

  // 497
  @Test("Spec 497: [link](/my uri) is literal text")
  func spec497() {
    let input = "[link](/my uri)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link](/my uri)")
  }

  // 498
  @Test("Spec 498: [link](</my uri>) with spaces in angle brackets")
  func spec498() {
    let input = "[link](</my uri>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "/my%20uri")
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/my%20uri\",title:\"\")[text(\"link\")]]]")
  }

  // 499
  @Test("Spec 499: newline in destination -> literal")
  func spec499() {
    let input = "[link](foo\nbar)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link](foo\nbar)")
  }

  // 500
  @Test("Spec 500: newline in angle-bracket destination -> literal")
  func spec500() {
    let input = "[link](<foo\nbar>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link](<foo\nbar>)")
  }

  // 501
  @Test("Spec 501: [a](<b)c>) -> href 'b)c'")
  func spec501() {
    let input = "[a](<b)c>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "b)c")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "a")
  }

  // 502
  @Test("Spec 502: [link](<foo\\>) is literal")
  func spec502() {
    let input = "[link](<foo\\>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link](<foo\\>)")
  }

  // 503
  @Test("Spec 503: mixed cases remain literal")
  func spec503() {
    let input = "[a](<b)c\n[a](<b)c>\n[a](<b>c)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[a](&lt;b)c\n[a](&lt;b)c&gt;\n[a](<b>c)")
  }

  // 504
  @Test("Spec 504: escaped parens in destination")
  func spec504() {
    let input = "[link](\\(foo\\))\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "(foo)")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"(foo)\",title:\"\")[text(\"link\")]]]")
  }

  // 505
  @Test("Spec 505: nested parens in destination")
  func spec505() {
    let input = "[link](foo(and(bar)))\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "foo(and(bar))")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"foo(and(bar))\",title:\"\")[text(\"link\")]]]")
  }

  // L3
  @Test("Spec L3: missing closing paren -> literal")
  func specL3() {
    let input = "[link](foo(and(bar))\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link](foo(and(bar))")
  }

  // 506
  @Test("Spec 506: escapes inside destination")
  func spec506() {
    let input = "[link](foo\\(and\\(bar\\))\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "foo(and(bar)")
  }

  // 507
  @Test("Spec 507: angle-bracket destination with parens")
  func spec507() {
    let input = "[link](<foo(and(bar)>)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "foo(and(bar)")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"foo(and(bar)\",title:\"\")[text(\"link\")]]]")
  }

  // 508
  @Test("Spec 508: escaped ) and : in destination")
  func spec508() {
    let input = "[link](foo\\)\\:)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count >= 1)
    guard let p = result.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode
    else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(a.url == "foo):")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
  }

  // 509
  @Test("Spec 509: fragments and query+fragment")
  func spec509() {
    let input =
      "[link](#fragment)\n\n[link](https://example.com#fragment)\n\n[link](https://example.com?foo=3#frag)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 3)
    for a in links {
      #expect(a.children.count == 1)
      #expect((a.children.first as? TextNode)?.content == "link")
    }
    #expect(links[0].url == "#fragment")
    #expect(links[1].url == "https://example.com#fragment")
    #expect(links[2].url == "https://example.com?foo=3#frag")
  }

  // 510
  @Test("Spec 510: backslash in destination percent-encoded")
  func spec510() {
    let input = "[link](foo\\bar)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "foo%5Cbar")
  }

  // 511
  @Test("Spec 511: entity decoded to UTF-8 then percent-encoded")
  func spec511() {
    let input = "[link](foo%20b&auml;)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "foo%20b%C3%A4")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"foo%20b%C3%A4\",title:\"\")[text(\"link\")]]]")
  }

  // 512
  @Test("Spec 512: title as destination -> becomes URL")
  func spec512() {
    let input = "[link](\"title\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "%22title%22")
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"%22title%22\",title:\"\")[text(\"link\")]]]")
  }

  // 513
  @Test("Spec 513: three title delimiter styles")
  func spec513() {
    let input = "[link](/url \"title\")\n[link](/url 'title')\n[link](/url (title))\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let links = findNodes(in: result.root, ofType: LinkNode.self)
    #expect(links.count == 3)
    for a in links {
      #expect(a.url == "/url" && a.title == "title")
      #expect(a.children.count == 1)
      #expect((a.children.first as? TextNode)?.content == "link")
    }
  }

  // 514
  @Test("Spec 514: quotes inside title")
  func spec514() {
    let input = "[link](/url \"title \\\"&quot;\\\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url")
    #expect(a.title == "title \"\"")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
  }

  // 515
  @Test("Spec 515: NBSP not treated as space before title => goes to URL")
  func spec515() {
    let input = "[link](/url\u{00A0}\"title\")\n"  // NBSP U+00A0 between URL and title
    let expectedURL = "/url%C2%A0%22title%22"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == expectedURL)
    #expect(a.title.isEmpty)
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
  }

  // 516
  @Test("Spec 516: invalid quoted title -> literal")
  func spec516() {
    let input = "[link](/url \"title \"and\" title\")\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
  }

  // 517
  @Test("Spec 517: single-quoted title with embedded double quotes")
  func spec517() {
    let input = "[link](/url 'title \"and\" title')\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url")
    #expect(a.title == "title \"and\" title")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
  }

  // 518
  @Test("Spec 518: destination on next line, then title")
  func spec518() {
    let input = "[link](   /uri\n  \"title\"  )\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let a = findNodes(in: result.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri" && a.title == "title")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "link")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/uri\",title:\"title\")[text(\"link\")]]]")
  }

  // 519
  @Test("Spec 519: space between label and ( makes literal")
  func spec519() {
    let input = "[link] (/uri)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link] (/uri)")
  }

  // 520
  @Test("Spec 520: nested brackets in label allowed")
  func spec520() {
    let input = "[link [foo [bar]]](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links[0].url == "/uri")
    #expect(innerText(links[0]) == "link [foo [bar]]")
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 1)
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link \\n+      [foo \\n+        [bar]\")]]]"
    )
  }

  // 521
  @Test("Spec 521: stray ] in label makes literal")
  func spec521() {
    let input = "[link] bar](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[link] bar](/uri)")
  }

  // 522
  @Test("Spec 522: inner autolink link remains; outer literal")
  func spec522() {
    let input = "[link [bar](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(links.first?.url == "/uri")
    #expect(innerText(links.first!) == "bar")
  }

  // 523
  @Test("Spec 523: escaped [ inside label")
  func spec523() {
    let input = "[link \\[[bar](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri")
    #expect(innerText(a) == "link [bar")
  }

  // 524
  @Test("Spec 524: strong/emphasis/code inside label")
  func spec524() {
    let input = "[link *foo **bar** `#`*](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri")
    // children: Text("link "), EmphasisNode(...)
    #expect((a.children.first as? TextNode)?.content == "link ")
    guard let em = a.children.dropFirst().first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(findNodes(in: em, ofType: StrongNode.self).count == 1)
    #expect(findNodes(in: em, ofType: InlineCodeNode.self).count == 1)
    #expect(childrenTypes(a) == [.text, .emphasis])
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"/uri\",title:\"\")[text(\"link \"),emphasis[text(\"foo \"),strong[text(\"bar\")],code(\"#\")]]]]"
    )
  }

  // 525
  @Test("Spec 525: image inside link")
  func spec525() {
    let input = "[![moon](moon.jpg)](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first,
      let img = findNodes(in: a, ofType: ImageNode.self).first
    else {
      Issue.record("Expected ImageNode inside LinkNode")
      return
    }
    #expect(a.url == "/uri")
    #expect(img.url == "moon.jpg" && img.alt == "moon")
    #expect(a.children.count == 1)
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"/uri\",title:\"\")[image(url:\"moon.jpg\",alt:\"moon\",title:\"\")]]]"
    )
  }

  // 526
  @Test("Spec 526: nested link invalid -> inner only")
  func spec526() {
    let input = "[foo [bar](/uri)](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1 && links[0].url == "/uri" && innerText(links[0]) == "bar")
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.text, .link, .text])
  }

  // 527
  @Test("Spec 527: nested link invalid inside emphasis -> inner only")
  func spec527() {
    let input = "[foo *[bar [baz](/uri)](/uri)*](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(innerText(links[0]) == "baz")
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(childrenTypes(p) == [.link])
  }

  // 528
  @Test("Spec 528: nested image becomes image with complex alt")
  func spec528() {
    let input = "![[[foo](uri1)](uri2)](uri3)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let img = findNodes(in: r.root, ofType: ImageNode.self).first else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(img.url == "uri3")
    #expect(img.alt == "[foo](uri2)")
  }

  // 529
  @Test("Spec 529: leading * literal before link")
  func spec529() {
    let input = "*[foo*](/uri)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count >= 2)
    #expect((p.children.first as? TextNode)?.content == "*")
    guard let link = p.children.dropFirst().first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/uri")
    #expect(innerText(link) == "foo*")
    #expect(childrenTypes(p).prefix(2) == [.text, .link])
  }

  // 530
  @Test("Spec 530: trailing * in destination stays in URL")
  func spec530() {
    let input = "[foo *bar](baz*)\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "baz*")
    #expect(innerText(a) == "foo *bar")
    #expect(childrenTypes(a) == [.text, .text])
  }

  // 531
  @Test("Spec 531: emphasis swallows opening [ -> no link")
  func spec531() {
    let input = "*foo [bar* baz]\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 532
  @Test("Spec 532: HTML-like label makes literal")
  func spec532() {
    let input = "[foo <bar attr=\"](baz)\">\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[foo <bar attr=\"](baz)\">")
  }

  // 533
  @Test("Spec 533: code span closes before link -> no link")
  func spec533() {
    let input = "[foo`](/uri)`\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 2)
    #expect((p.children[0] as? TextNode)?.content == "[foo")
    #expect((p.children[1] as? InlineCodeNode)?.code == "](/uri)")
  }

  // 534
  @Test("Spec 534: autolink eats following ](uri) as text")
  func spec534() {
    let input = "[foo<https://example.com/?search=](uri)>\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count >= 2)
    #expect((p.children.first as? TextNode)?.content == "[foo")
    guard let link = p.children.dropFirst().first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://example.com/?search=%5D(uri)")
    #expect(innerText(link) == "https://example.com/?search=](uri)")
    #expect(childrenTypes(p).prefix(2) == [.text, .link])
  }

  // 535
  @Test("Spec 535: reference link basic")
  func spec535() {
    let input = "[foo][bar]\n\n[bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "foo")
  }

  // 536
  @Test("Spec 536: nested brackets in ref label")
  func spec536() {
    let input = "[link [foo [bar]]][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri")
    #expect(innerText(a) == "link [foo [bar]]")
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 1)
  }

  // 537
  @Test("Spec 537: escaped [ in ref label")
  func spec537() {
    let input = "[link \\[bar][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri")
    #expect(innerText(a) == "link [bar")
  }

  // 538
  @Test("Spec 538: formatting inside ref link")
  func spec538() {
    let input = "[link *foo **bar** `#`*][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri")
    #expect(findNodes(in: a, ofType: EmphasisNode.self).count == 1)
    #expect(findNodes(in: a, ofType: StrongNode.self).count == 1)
    #expect(findNodes(in: a, ofType: InlineCodeNode.self).count == 1)
  }

  // 539
  @Test("Spec 539: image inside ref link")
  func spec539() {
    let input = "[![moon](moon.jpg)][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first,
      let img = findNodes(in: a, ofType: ImageNode.self).first
    else {
      Issue.record("Expected image inside link")
      return
    }
    #expect(a.url == "/uri")
    #expect(img.url == "moon.jpg" && img.alt == "moon")
    #expect(a.children.count == 1)
  }

  // 540
  @Test("Spec 540: inner inline link + ref link to 'ref'")
  func spec540() {
    let input = "[foo [bar](/uri)][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 2)
    #expect(innerText(links[0]) == "bar" && links[0].url == "/uri")
    #expect(innerText(links[1]) == "ref" && links[1].url == "/uri")
  }

  // 541
  @Test("Spec 541: inner inline link inside emphasis + ref link")
  func spec541() {
    let input = "[foo *bar [baz][ref]*][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 2)
    #expect(innerText(links[0]) == "baz" && links[0].url == "/uri")
    #expect(innerText(links[1]) == "ref" && links[1].url == "/uri")
  }

  // 542
  @Test("Spec 542: literal * around ref link")
  func spec542() {
    let input = "*[foo*][ref]\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect((p.children.first as? TextNode)?.content == "*")
    guard let a = p.children.dropFirst().first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(innerText(a) == "foo*")
    #expect(childrenTypes(p).prefix(2) == [.text, .link])
  }

  // 543
  @Test("Spec 543: trailing * after ref link literal")
  func spec543() {
    let input = "[foo *bar][ref]*\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode,
      let t = p.children.dropFirst().first as? TextNode
    else {
      Issue.record("Expected Link then trailing text")
      return
    }
    #expect(innerText(a) == "foo *bar")
    #expect(t.content == "*")
    #expect(childrenTypes(p).prefix(2) == [.link, .text])
  }

  // 544
  @Test("Spec 544: HTML-like label -> literal")
  func spec544() {
    let input = "[foo <bar attr=\"][ref]\">\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 545
  @Test("Spec 545: code span in label breaks ref link")
  func spec545() {
    let input = "[foo`][ref]`\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(findNodes(in: p, ofType: InlineCodeNode.self).count == 1)
    #expect(findNodes(in: p, ofType: LinkNode.self).isEmpty)
    #expect(childrenTypes(p) == [.code])
  }

  // 546
  @Test("Spec 546: autolink consumes following ][ref]")
  func spec546() {
    let input = "[foo<https://example.com/?search=][ref]>\n\n[ref]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let link = findNodes(in: p, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://example.com/?search=%5D%5Bref%5D")
    #expect(innerText(link) == "https://example.com/?search=][ref]")
    #expect(childrenTypes(p) == [.link])
  }

  // 547
  @Test("Spec 547: case-insensitive reference label")
  func spec547() {
    let input = "[foo][BaR]\n\n[bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "foo")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]]]")
  }

  // 548
  @Test("Spec 548: unicode case fold for label (ẞ vs SS)")
  func spec548() {
    let input = "[ẞ]\n\n[SS]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && innerText(a) == "ẞ")
  }

  // 549
  @Test("Spec 549: multi-line definition label")
  func spec549() {
    let input = "[Foo\n  bar]: /url\n\n[Baz][Foo bar]\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && innerText(a) == "Baz")
    #expect(a.children.count == 1)
    #expect((a.children.first as? TextNode)?.content == "Baz")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"Baz\")]]]")
  }

  // 550
  @Test("Spec 550: space-separated [foo] [bar]")
  func spec550() {
    let input = "[foo] [bar]\n\n[bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(innerText(links[0]) == "bar" && links[0].url == "/url" && links[0].title == "title")
  }

  // 551
  @Test("Spec 551: stacked vertically [foo]\n[bar]")
  func spec551() {
    let input = "[foo]\n[bar]\n\n[bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(innerText(links[0]) == "bar" && links[0].url == "/url" && links[0].title == "title")
  }

  // 552
  @Test("Spec 552: first definition wins")
  func spec552() {
    let input = "[foo]: /url1\n\n[foo]: /url2\n\n[bar][foo]\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url1" && innerText(a) == "bar")
  }

  // 553
  @Test("Spec 553: escaped ! in reference label prevents match")
  func spec553() {
    let input = "[bar][foo\\!]\n\n[foo!]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 554
  @Test("Spec 554: malformed reference definition -> literal")
  func spec554() {
    let input = "[foo][ref[]\n\n[ref[]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 555
  @Test("Spec 555: nested [] in reference label -> literal")
  func spec555() {
    let input = "[foo][ref[bar]]\n\n[ref[bar]]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 556
  @Test("Spec 556: [[[foo]]] with def remains literal")
  func spec556() {
    let input = "[[[foo]]]\n\n[[[foo]]]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 557
  @Test("Spec 557: escaped [ in ref label allows match")
  func spec557() {
    let input = "[foo][ref\\[]\n\n[ref\\[]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri" && innerText(a) == "foo")
  }

  // 558
  @Test("Spec 558: backslash at end of label name")
  func spec558() {
    let input = "[bar\\\\]: /uri\n\n[bar\\\\]\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/uri" && innerText(a) == "bar\\")
  }

  // 559
  @Test("Spec 559: empty [] then def; first stays literal")
  func spec559() {
    let input = "[]\n\n[]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[]")
  }

  // 560
  @Test("Spec 560: bracket across lines stays literal")
  func spec560() {
    let input = "[\n ]\n\n[\n ]: /uri\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[\n ]")
  }

  // 561
  @Test("Spec 561: collapsed reference")
  func spec561() {
    let input = "[foo][]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]]]")
  }

  // 562
  @Test("Spec 562: collapsed ref with emphasis in label")
  func spec562() {
    let input = "[*foo* bar][]\n\n[*foo* bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title")
    #expect(findNodes(in: a, ofType: EmphasisNode.self).count == 1)
  }

  // 563
  @Test("Spec 563: case-insensitive collapsed ref label")
  func spec563() {
    let input = "[Foo][]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "Foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"Foo\")]]]")
  }

  // 564
  @Test("Spec 564: collapsed ref cannot be split across paragraphs")
  func spec564() {
    let input = "[foo] \n[]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let links = findNodes(in: p, ofType: LinkNode.self)
    #expect(links.count == 1 && innerText(links[0]) == "foo")
    #expect((p.children.last as? TextNode)?.content == "[]")
  }

  // 565
  @Test("Spec 565: shortcut reference")
  func spec565() {
    let input = "[foo]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]]]")
  }

  // 566
  @Test("Spec 566: shortcut reference with emphasis in label")
  func spec566() {
    let input = "[*foo* bar]\n\n[*foo* bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title")
    #expect(findNodes(in: a, ofType: EmphasisNode.self).count == 1)
  }

  // 567
  @Test("Spec 567: extra [ around shortcut -> literal bracketed link")
  func spec567() {
    let input = "[[*foo* bar]]\n\n[*foo* bar]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(findNodes(in: p, ofType: LinkNode.self).count == 1)
    #expect((p.children.first as? TextNode)?.content == "[")
  }

  // 568
  @Test("Spec 568: nested [foo] across newline stays literal")
  func spec568() {
    let input = "[[bar [foo]\n\n[foo]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 569
  @Test("Spec 569: capitalized shortcut reference works")
  func spec569() {
    let input = "[Foo]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url" && a.title == "title" && innerText(a) == "Foo")
  }

  // 570
  @Test("Spec 570: shortcut link followed by text")
  func spec570() {
    let input = "[foo] bar\n\n[foo]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode,
      let a = p.children.first as? LinkNode,
      let t = p.children.dropFirst().first as? TextNode
    else {
      Issue.record("Expected Link then text")
      return
    }
    #expect(a.url == "/url" && innerText(a) == "foo")
    #expect(t.content == " bar")
    #expect(
      sig(r.root)
        == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")],text(\" bar\")]]")
  }

  // 571
  @Test("Spec 571: escaped [ prevents link")
  func spec571() {
    let input = "\\[foo]\n\n[foo]: /url \"title\"\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    #expect(findNodes(in: r.root, ofType: LinkNode.self).isEmpty)
  }

  // 572
  @Test("Spec 572: definition 'foo*' and usage '*[foo*]'")
  func spec572() {
    let input = "[foo*]: /url\n\n*[foo*]\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect((p.children.first as? TextNode)?.content == "*")
    guard let a = p.children.dropFirst().first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(innerText(a) == "foo*")
  }

  // 573
  @Test("Spec 573: multiple definitions; choose 'bar'")
  func spec573() {
    let input = "[foo][bar]\n\n[foo]: /url1\n[bar]: /url2\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url2" && innerText(a) == "foo")
  }

  // 574
  @Test("Spec 574: collapsed ref uses its own label")
  func spec574() {
    let input = "[foo][]\n\n[foo]: /url1\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url1" && innerText(a) == "foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"/url1\",title:\"\")[text(\"foo\")]]]")
  }

  // 575
  @Test("Spec 575: inline empty dest takes precedence over def")
  func spec575() {
    let input = "[foo]()\n\n[foo]: /url1\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let a = findNodes(in: r.root, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "" && innerText(a) == "foo")
    #expect(sig(r.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"foo\")]]]")
  }

  // 576
  @Test("Spec 576: inline (not a link) then shortcut resolves")
  func spec576() {
    let input = "[foo](not a link)\n\n[foo]: /url1\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(findNodes(in: p, ofType: LinkNode.self).count == 1)
    guard let a = findNodes(in: p, ofType: LinkNode.self).first else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(a.url == "/url1" && innerText(a) == "foo")
    #expect((p.children.last as? TextNode)?.content == "(not a link)")
  }

  // 577
  @Test("Spec 577: chained refs; later def applies to baz")
  func spec577() {
    let input = "[foo][bar][baz]\n\n[baz]: /url\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(innerText(links[0]) == "bar" && links[0].url == "/url")
  }

  // 578
  @Test("Spec 578: chained refs resolved independently")
  func spec578() {
    let input = "[foo][bar][baz]\n\n[baz]: /url1\n[bar]: /url2\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 2)
    #expect(innerText(links[0]) == "foo" && links[0].url == "/url2")
    #expect(innerText(links[1]) == "baz" && links[1].url == "/url1")
  }

  // 579
  @Test("Spec 579: chained refs with foo defined -> only bar resolved")
  func spec579() {
    let input = "[foo][bar][baz]\n\n[baz]: /url1\n[foo]: /url2\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    let links = findNodes(in: r.root, ofType: LinkNode.self)
    #expect(links.count == 1)
    #expect(innerText(links[0]) == "bar" && links[0].url == "/url1")
  }

}

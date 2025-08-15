import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Emphasis and Strong (Strict)")
struct MarkdownEmphasisStrongTests {
  private let h = MarkdownTestHarness()

  // Helpers
  private func firstParagraph(_ input: String) -> ParagraphNode? {
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    return result.root.children.first as? ParagraphNode
  }

  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    var acc: [String] = []
    func walk(_ n: CodeNode<MarkdownNodeElement>) {
      if let t = n as? TextNode { acc.append(t.content) }
      for c in n.children { walk(c) }
    }
    walk(node)
    return acc.joined()
  }

  // 360: *foo bar*
  @Test("Spec 360: emphasis with asterisks around words")
  func spec360() {
    let input = "*foo bar*\n"
    guard let para = firstParagraph(input) else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "foo bar")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo bar\")]]")
  }

  // 361: a * foo bar*
  @Test("Spec 361: not emphasis due to space before word")
  func spec361() {
    let input = "a * foo bar*\n"
    guard let para = firstParagraph(input) else { return }
    let ems = para.children.compactMap { $0 as? EmphasisNode }
    let strs = para.children.compactMap { $0 as? StrongNode }
    #expect(ems.isEmpty && strs.isEmpty)
    #expect(sig(para) == "paragraph[text(\"a * foo bar*\")]")
  }

  // 362: a*"foo"* -> no emphasis
  @Test("Spec 362: punctuation adjacent to '*' prevents emphasis")
  func spec362() {
    let input = "a*\"foo\"*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "a*\"foo\"*")
    #expect(sig(para) == "paragraph[text(\"a*\\\"foo\\\"*\")]")
  }

  // 363: * a * (NBSP) -> no emphasis
  @Test("Spec 363: NBSP around text prevents emphasis, remains literal")
  func spec363() {
    let input = "* a *\n"  // NBSP characters
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "* a *")
    #expect(sig(para) == "paragraph[text(\"* a *\")]")
  }

  // E1: *$*alpha. / *£*bravo. / *€*charlie. -> no emphasis in any
  @Test("Spec E1: currency symbols adjacent to '*' -> no emphasis (three paragraphs)")
  func specE1() {
    let input = "*$*alpha.\n\n*£*bravo.\n\n*€*charlie.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    let p1 = result.root.children[0] as? ParagraphNode
    let p2 = result.root.children[1] as? ParagraphNode
    let p3 = result.root.children[2] as? ParagraphNode
    #expect(p1 != nil && p2 != nil && p3 != nil)
    #expect((p1?.children.first as? TextNode)?.content == "*$*alpha.")
    #expect((p2?.children.first as? TextNode)?.content == "*£*bravo.")
    #expect((p3?.children.first as? TextNode)?.content == "*€*charlie.")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"*$*alpha.\")],paragraph[text(\"*£*bravo.\")],paragraph[text(\"*€*charlie.\")]]"
    )
  }

  // 364: foo*bar* -> emphasis around bar
  @Test("Spec 364: emphasis after text with asterisks")
  func spec364() {
    let input = "foo*bar*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "foo")
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "bar")
    #expect(sig(para) == "paragraph[text(\"foo\"),emphasis[text(\"bar\")]]")
  }

  // 365: 5*6*78 -> emphasis around 6
  @Test("Spec 365: emphasis between digits with asterisks")
  func spec365() {
    let input = "5*6*78\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "5")
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "6")
    #expect((para.children[2] as? TextNode)?.content == "78")
    #expect(sig(para) == "paragraph[text(\"5\"),emphasis[text(\"6\")],text(\"78\")]")
  }

  // 366: _foo bar_ -> emphasis with underscores
  @Test("Spec 366: underscore emphasis around words")
  func spec366() {
    let input = "_foo bar_\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "foo bar")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo bar\")]]")
  }

  // 367: _ foo bar_ -> no emphasis
  @Test("Spec 367: space after underscore opener prevents emphasis")
  func spec367() {
    let input = "_ foo bar_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "_ foo bar_")
    #expect(sig(para) == "paragraph[text(\"_ foo bar_\")]")
  }

  // 368: a_"foo"_ -> no emphasis
  @Test("Spec 368: punctuation adjacent to '_' prevents emphasis")
  func spec368() {
    let input = "a_\"foo\"_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "a_\"foo\"_")
    #expect(sig(para) == "paragraph[text(\"a_\\\"foo\\\"_\")]")
  }

  // 369: foo_bar_ -> no emphasis
  @Test("Spec 369: intraword underscore prevents emphasis (trailing underscore remains)")
  func spec369() {
    let input = "foo_bar_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "foo_bar_")
    #expect(sig(para) == "paragraph[text(\"foo_bar_\")]")
  }

  // 370: 5_6_78 -> no emphasis
  @Test("Spec 370: digits with underscores do not form emphasis")
  func spec370() {
    let input = "5_6_78\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "5_6_78")
    #expect(sig(para) == "paragraph[text(\"5_6_78\")]")
  }

  // 371: пристаням_стремятся_ -> no emphasis
  @Test("Spec 371: non-Latin intraword underscore -> no emphasis")
  func spec371() {
    let input = "пристаням_стремятся_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "пристаням_стремятся_")
    #expect(sig(para) == "paragraph[text(\"пристаням_стремятся_\")]")
  }

  // 372: aa_"bb"_cc -> no emphasis
  @Test("Spec 372: underscores around punctuation inside word -> no emphasis")
  func spec372() {
    let input = "aa_\"bb\"_cc\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "aa_\"bb\"_cc")
    #expect(sig(para) == "paragraph[text(\"aa_\\\"bb\\\"_cc\")]")
  }

  // 373: foo-_(bar)_ -> emphasis with underscores
  @Test("Spec 373: underscore emphasis around parenthesized text")
  func spec373() {
    let input = "foo-_(bar)_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "foo-")
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "(bar)")
    #expect(sig(para) == "paragraph[text(\"foo-\"),emphasis[text(\"(bar)\")]]")
  }

  // 374: _foo* -> no emphasis
  @Test("Spec 374: unmatched markers across types -> no emphasis")
  func spec374() {
    let input = "_foo*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "_foo*")
    #expect(sig(para) == "paragraph[text(\"_foo*\")]")
  }

  // 375: *foo bar * -> no emphasis due to space before closer
  @Test("Spec 375: trailing space before '*' closer prevents emphasis")
  func spec375() {
    let input = "*foo bar *\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "*foo bar *")
    #expect(sig(para) == "paragraph[text(\"*foo bar *\")]")
  }

  // 376: *foo bar\n* -> no emphasis across line
  @Test("Spec 376: newline breaks emphasis; remains literal with line break")
  func spec376() {
    let input = "*foo bar\n*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    // Expect a LineBreakNode between two text chunks
    #expect(para.children.contains { $0 is LineBreakNode } == true)
    let texts = para.children.compactMap { $0 as? TextNode }.map { $0.content }
    #expect(texts.first == "*foo bar")
    #expect(texts.last == "*")
    // Strict sig with soft line break between two text nodes
    #expect(sig(para) == "paragraph[text(\"*foo bar\"),line_break(soft),text(\"*\")]")
  }

  // 377: *(*foo) -> no emphasis
  @Test("Spec 377: '(' immediately after '*' prevents opener")
  func spec377() {
    let input = "*(*foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "*(*foo)")
    #expect(sig(para) == "paragraph[text(\"*(*foo)\")]")
  }

  // 378: *(*foo*)* -> nested emphasis
  @Test("Spec 378: nested emphasis with asterisks")
  func spec378() {
    let input = "*(*foo*)*\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? EmphasisNode else {
      Issue.record("Expected outer EmphasisNode")
      return
    }
    #expect(outer.children.count == 3)
    #expect((outer.children[0] as? TextNode)?.content == "(")
    guard let inner = outer.children[1] as? EmphasisNode else {
      Issue.record("Expected inner EmphasisNode")
      return
    }
    #expect(innerText(inner) == "foo")
    #expect((outer.children[2] as? TextNode)?.content == ")")
    #expect(sig(para) == "paragraph[emphasis[text(\"(\"),emphasis[text(\"foo\")],text(\")\")]]")
  }

  // 379: *foo*bar -> emphasis then text
  @Test("Spec 379: emphasis followed by trailing text")
  func spec379() {
    let input = "*foo*bar\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children[0] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at start")
      return
    }
    #expect(innerText(em) == "foo")
    #expect((para.children[1] as? TextNode)?.content == "bar")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\")],text(\"bar\")]")
  }

  // 380: _foo bar _ -> no emphasis
  @Test("Spec 380: trailing space before underscore closer -> no emphasis")
  func spec380() {
    let input = "_foo bar _\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_foo bar _\")]")
  }

  // 381: _(_foo) -> no emphasis
  @Test("Spec 381: underscore opener followed by paren -> no emphasis")
  func spec381() {
    let input = "_(_foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_(_foo)\")]")
  }

  // 382: _(_foo_)_ -> nested emphasis
  @Test("Spec 382: nested emphasis with underscores")
  func spec382() {
    let input = "_(_foo_)_\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? EmphasisNode else {
      Issue.record("Expected outer EmphasisNode")
      return
    }
    #expect(outer.children.count == 3)
    #expect((outer.children[0] as? TextNode)?.content == "(")
    guard let inner = outer.children[1] as? EmphasisNode else {
      Issue.record("Expected inner EmphasisNode")
      return
    }
    #expect(innerText(inner) == "foo")
    #expect((outer.children[2] as? TextNode)?.content == ")")
    #expect(sig(para) == "paragraph[emphasis[text(\"(\"),emphasis[text(\"foo\")],text(\")\")]]")
  }

  // 383: _foo_bar -> no emphasis
  @Test("Spec 383: intraword underscore -> no emphasis")
  func spec383() {
    let input = "_foo_bar\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_foo_bar\")]")
  }

  // 384: _пристаням_стремятся -> no emphasis
  @Test("Spec 384: non-Latin intraword underscore -> no emphasis")
  func spec384() {
    let input = "_пристаням_стремятся\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_пристаням_стремятся\")]")
  }

  // 385: _foo_bar_baz_ -> emphasis of whole
  @Test("Spec 385: underscore emphasis over compound word")
  func spec385() {
    let input = "_foo_bar_baz_\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "foo_bar_baz")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo_bar_baz\")]]")
  }

  // 386: _(bar)_. -> emphasis then trailing period
  @Test("Spec 386: underscore emphasis with trailing period")
  func spec386() {
    let input = "_(bar)_.\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode as first")
      return
    }
    #expect(innerText(em) == "(bar)")
    #expect((para.children.last as? TextNode)?.content == ".")
    #expect(sig(para) == "paragraph[emphasis[text(\"(bar)\")],text(\".\")]")
  }

  // 387: **foo bar** -> strong
  @Test("Spec 387: strong with asterisks")
  func spec387() {
    let input = "**foo bar**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo bar")
    #expect(sig(para) == "paragraph[strong[text(\"foo bar\")]]")
  }

  // 388: ** foo bar** -> no strong
  @Test("Spec 388: space after opener prevents strong")
  func spec388() {
    let input = "** foo bar**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"** foo bar**\")]")
  }

  // 389: a**"foo"** -> no strong
  @Test("Spec 389: punctuation adjacent strong markers -> no strong")
  func spec389() {
    let input = "a**\"foo\"**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"a**\\\"foo\\\"**\")]")
  }

  // 390: foo**bar** -> strong after text
  @Test("Spec 390: trailing strong after text")
  func spec390() {
    let input = "foo**bar**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "foo")
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "bar")
    #expect(sig(para) == "paragraph[text(\"foo\"),strong[text(\"bar\")]]")
  }

  // 391: __foo bar__ -> strong underscore
  @Test("Spec 391: strong with underscores")
  func spec391() {
    let input = "__foo bar__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo bar")
    #expect(sig(para) == "paragraph[strong[text(\"foo bar\")]]")
  }

  // 392: __ foo bar__ -> no strong
  @Test("Spec 392: space after underscore opener -> no strong")
  func spec392() {
    let input = "__ foo bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__ foo bar__\")]")
  }

  // 393: __\nfoo bar__ -> no strong across line
  @Test("Spec 393: newline breaks strong")
  func spec393() {
    let input = "__\nfoo bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__\\nfoo bar__\")]")
  }

  // 394: a__"foo"__ -> no strong
  @Test("Spec 394: punctuation adjacent underscore strong -> no strong")
  func spec394() {
    let input = "a__\"foo\"__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"a__\\\"foo\\\"__\")]")
  }

  // 395: foo__bar__ -> no strong
  @Test("Spec 395: literal double underscores intraword -> no strong")
  func spec395() {
    let input = "foo__bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"foo__bar__\")]")
  }

  // 396: 5__6__78 -> no strong
  @Test("Spec 396: digits with double underscores -> no strong")
  func spec396() {
    let input = "5__6__78\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"5__6__78\")]")
  }

  // 397: пристаням__стремятся__ -> no strong
  @Test("Spec 397: non-Latin intraword double underscore -> no strong")
  func spec397() {
    let input = "пристаням__стремятся__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"пристаням__стремятся__\")]")
  }

  // 398: __foo, __bar__, baz__ -> nested strong
  @Test("Spec 398: nested strong inside strong")
  func spec398() {
    let input = "__foo, __bar__, baz__\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? StrongNode else {
      Issue.record("Expected outer StrongNode")
      return
    }
    #expect(outer.children.count == 3)
    #expect((outer.children[0] as? TextNode)?.content == "foo, ")
    guard let inner = outer.children[1] as? StrongNode else {
      Issue.record("Expected inner StrongNode")
      return
    }
    #expect(innerText(inner) == "bar")
    #expect((outer.children[2] as? TextNode)?.content == ", baz")
    #expect(sig(para) == "paragraph[strong[text(\"foo, \"),strong[text(\"bar\")],text(\", baz\")]]")
  }

  // 399: foo-__(bar)__ -> strong around (bar)
  @Test("Spec 399: strong around parenthesized text")
  func spec399() {
    let input = "foo-__(bar)__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "foo-")
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "(bar)")
    #expect(sig(para) == "paragraph[text(\"foo-\"),strong[text(\"(bar)\")]]")
  }

  // 400: **foo bar ** -> no strong
  @Test("Spec 400: trailing space before closer prevents strong")
  func spec400() {
    let input = "**foo bar **\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"**foo bar **\")]")
  }

  // 401: **(**foo) -> no strong
  @Test("Spec 401: opener immediately followed by ( -> no strong")
  func spec401() {
    let input = "**(**foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"**(**foo)\")]")
  }

  // 402: *(**foo**)* -> emphasis containing strong
  @Test("Spec 402: emphasis around strong")
  func spec402() {
    let input = "*(**foo**)*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.count == 3)
    #expect((em.children[0] as? TextNode)?.content == "(")
    guard let strong = em.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode inside Emphasis")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect((em.children[2] as? TextNode)?.content == ")")
    #expect(sig(para) == "paragraph[emphasis[text(\"(\"),strong[text(\"foo\")],text(\")\")]]")
  }

  // 403: **Gomphocarpus (*...*, *...*)** nested
  @Test("Spec 403: strong containing nested emphasis over lines")
  func spec403() {
    let input = "**Gomphocarpus (*Gomphocarpus physocarpus*, syn.\n*Asclepias physocarpa*)**\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    // Sanity: includes two EmphasisNode children inside
    let innerEms = strong.children.compactMap { $0 as? EmphasisNode }
    #expect(innerEms.count == 2)
    // Deterministic signature for paragraph with strong containing two emphasis around a soft break
    #expect(
      sig(para)
        == "paragraph[strong[emphasis[text(\"Gomphocarpus\")],text(\" (\"),emphasis[text(\"Gomphocarpus physocarpus, syn.\")],line_break(soft),text(\"Asclepias physocarpa)\")]]]"
    )
  }

  // 404: **foo "*bar*" foo**
  @Test("Spec 404: strong containing emphasis")
  func spec404() {
    let input = "**foo \"*bar*\" foo**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    let ems = findNodes(in: strong, ofType: EmphasisNode.self)
    #expect(ems.count == 1)
    #expect(innerText(ems[0]) == "bar")
    #expect(
      sig(para)
        == "paragraph[strong[text(\"foo \\\"\"),emphasis[text(\"bar\")],text(\"\\\" foo\")]]")
  }

  // 405: **foo**bar -> strong then text
  @Test("Spec 405: strong followed by text")
  func spec405() {
    let input = "**foo**bar\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[0] as? StrongNode else {
      Issue.record("Expected StrongNode at start")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect((para.children[1] as? TextNode)?.content == "bar")
    #expect(sig(para) == "paragraph[strong[text(\"foo\")],text(\"bar\")]")
  }

  // 406: __foo bar __ -> no strong
  @Test("Spec 406: trailing space before underscore closer -> no strong")
  func spec406() {
    let input = "__foo bar __\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__foo bar __\")]")
  }

  // 407: __(__foo) -> no strong
  @Test("Spec 407: underscore strong opener followed by ( -> no strong")
  func spec407() {
    let input = "__(__foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__(__foo)\")]")
  }

  // 408: _(__foo__)_ -> emphasis containing strong
  @Test("Spec 408: underscore emphasis around strong")
  func spec408() {
    let input = "_(__foo__)_\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    let strongs = em.children.compactMap { $0 as? StrongNode }
    #expect(strongs.count == 1)
    #expect(innerText(strongs[0]) == "foo")
    #expect(sig(para) == "paragraph[emphasis[text(\"(\"),strong[text(\"foo\")],text(\")\")]]")
  }

  // 409: __foo__bar -> no split strong
  @Test("Spec 409: strong then literal 'bar'")
  func spec409() {
    let input = "__foo__bar\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[0] as? StrongNode else {
      Issue.record("Expected StrongNode at start")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect((para.children[1] as? TextNode)?.content == "bar")
    #expect(sig(para) == "paragraph[strong[text(\"foo\")],text(\"bar\")]")
  }

  // 410: __пристаням__стремятся -> no strong intraword
  @Test("Spec 410: non-Latin intraword double underscore -> no strong")
  func spec410() {
    let input = "__пристаням__стремятся\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__пристаням__стремятся\")]")
  }

  // 411: __foo__bar__baz__ -> strong around whole
  @Test("Spec 411: outer strong with intraword underscores inside")
  func spec411() {
    let input = "__foo__bar__baz__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo__bar__baz")
    #expect(sig(para) == "paragraph[strong[text(\"foo__bar__baz\")]]")
  }

  // 412: __(bar)__. -> strong then period
  @Test("Spec 412: strong with trailing period")
  func spec412() {
    let input = "__(bar)__.\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "(bar)")
    #expect((para.children.last as? TextNode)?.content == ".")
    #expect(sig(para) == "paragraph[strong[text(\"(bar)\")],text(\".\")]")
  }

  // 413: *foo [bar](/url)* -> emphasis around link
  @Test("Spec 413: emphasis around link")
  func spec413() {
    let input = "*foo [bar](/url)*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is LinkNode } == true)
    #expect(
      sig(para)
        == "paragraph[emphasis[text(\"foo \"),link(url:\"/url\",title:\"\")[text(\"bar\")]]]")
  }

  // 414: *foo\nbar* -> emphasis spanning line break
  @Test("Spec 414: emphasis spans newline")
  func spec414() {
    let input = "*foo\nbar*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    // Deterministic: exact children text nodes separated by soft break
    #expect(sig(em) == "emphasis[text(\"foo\"),line_break(soft),text(\"bar\")]")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\"),line_break(soft),text(\"bar\")]]")
  }

  // 415: _foo __bar__ baz_
  @Test("Spec 415: emphasis containing strong inside")
  func spec415() {
    let input = "_foo __bar__ baz_\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" baz\")]]")
  }

  // 416: _foo _bar_ baz_
  @Test("Spec 416: emphasis containing emphasis")
  func spec416() {
    let input = "_foo _bar_ baz_\n"
    guard let para = firstParagraph(input) else { return }
    guard let emOuter = para.children.first as? EmphasisNode else {
      Issue.record("Expected outer EmphasisNode")
      return
    }
    #expect(emOuter.children.contains { $0 is EmphasisNode } == true)
    #expect(
      sig(para) == "paragraph[emphasis[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]")
  }

  // 417: __foo_ bar_
  @Test("Spec 417: emphasis nested then outer emphasis")
  func spec417() {
    let input = "__foo_ bar_\n"
    guard let para = firstParagraph(input) else { return }
    // Should be Emphasis(Emphasis(foo) + ' bar')
    guard let emOuter = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(emOuter.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[emphasis[emphasis[text(\"foo\")],text(\" bar\")]]")
  }

  // 418: *foo *bar** -> nested emphasis
  @Test("Spec 418: emphasis nesting with closing strong")
  func spec418() {
    let input = "*foo *bar**\n"
    guard let para = firstParagraph(input) else { return }
    guard let emOuter = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(emOuter.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo \"),emphasis[text(\"bar\")]]]")
  }

  // 419: *foo **bar** baz*
  @Test("Spec 419: emphasis containing strong in middle")
  func spec419() {
    let input = "*foo **bar** baz*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")],text(\" baz\")]]")
  }

  // 420: *foo**bar**baz*
  @Test("Spec 420: emphasis with strong inside contiguous text")
  func spec420() {
    let input = "*foo**bar**baz*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\"),strong[text(\"bar\")],text(\"baz\")]]")
  }

  // 421: *foo**bar* -> not closed properly, remains literal in emphasis
  @Test("Spec 421: unmatched strong closer inside emphasis")
  func spec421() {
    let input = "*foo**bar*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(innerText(em) == "foo**bar")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo**bar\")]]")
  }

  // 422: ***foo** bar*
  @Test("Spec 422: emphasis around strong then text")
  func spec422() {
    let input = "***foo** bar*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[strong[text(\"foo\")],text(\" bar\")]]")
  }

  // 423: *foo **bar***
  @Test("Spec 423: emphasis containing strong at end")
  func spec423() {
    let input = "*foo **bar***\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo \"),strong[text(\"bar\")]]]")
  }

  // 424: *foo**bar***
  @Test("Spec 424: emphasis containing strong tightly")
  func spec424() {
    let input = "*foo**bar***\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\"),strong[text(\"bar\")]]]")
  }

  // 425: foo***bar***baz
  @Test("Spec 425: text then emphasis(strong) then text")
  func spec425() {
    let input = "foo***bar***baz\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "foo")
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode in middle")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect((para.children[2] as? TextNode)?.content == "baz")
    #expect(sig(para) == "paragraph[text(\"foo\"),emphasis[strong[text(\"bar\")]],text(\"baz\")]")
  }

  // 426: foo******bar*********baz -> nested strongs then leftover stars
  @Test("Spec 426: multiple strong nestings then leftover stars")
  func spec426() {
    let input = "foo******bar*********baz\n"
    guard let para = firstParagraph(input) else { return }
    // At least one Strong inside, and trailing text contains ***baz per HTML
    #expect(para.children.contains { $0 is StrongNode } == true)
    // Deterministic checks: first child is text "foo", last child is text ending with "baz"
    #expect((para.children.first as? TextNode)?.content == "foo")
    #expect((para.children.last as? TextNode)?.content == "baz")
  }

  // 427: *foo **bar *baz* bim** bop*
  @Test("Spec 427: nested emphasis inside strong inside emphasis")
  func spec427() {
    let input = "*foo **bar *baz* bim** bop*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    // Contains Strong which contains Emphasis
    let strongs = em.children.compactMap { $0 as? StrongNode }
    #expect(strongs.isEmpty == false)
    let innerEms = strongs.flatMap { $0.children.compactMap { $0 as? EmphasisNode } }
    #expect(innerEms.isEmpty == false)
    // Deterministic: emphasis contains strong which contains emphasis("baz")
    #expect(
      sig(para)
        == "paragraph[emphasis[text(\"foo \"),strong[text(\"bar \"),emphasis[text(\"baz\")],text(\" bim\")],text(\" bop\")]]"
    )
  }

  // 428: *foo [*bar*](/url)* -> emphasis around link containing emphasis
  @Test("Spec 428: emphasis around link that contains emphasis")
  func spec428() {
    let input = "*foo [*bar*](/url)*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is LinkNode } == true)
    let links = em.children.compactMap { $0 as? LinkNode }
    let nestedEm = links.first?.children.contains { $0 is EmphasisNode } ?? false
    #expect(nestedEm)
    #expect(
      sig(para)
        == "paragraph[emphasis[text(\"foo \"),link(url:\"/url\",title:\"\")[emphasis[text(\"bar\")]]]"
    )
  }

  // 429: ** is not an empty emphasis -> literal
  @Test("Spec 429: literal '** is not an empty emphasis'")
  func spec429() {
    let input = "** is not an empty emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "** is not an empty emphasis")
    #expect(sig(para) == "paragraph[text(\"** is not an empty emphasis\")]")
  }

  // 430: **** is not an empty strong emphasis -> literal
  @Test("Spec 430: literal '**** is not an empty strong emphasis'")
  func spec430() {
    let input = "**** is not an empty strong emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "**** is not an empty strong emphasis")
    #expect(sig(para) == "paragraph[text(\"**** is not an empty strong emphasis\")]")
  }

  // 431: **foo [bar](/url)** -> strong around link
  @Test("Spec 431: strong around link")
  func spec431() {
    let input = "**foo [bar](/url)**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is LinkNode } == true)
    #expect(
      sig(para) == "paragraph[strong[text(\"foo \"),link(url:\"/url\",title:\"\")[text(\"bar\")]]]")
  }

  // 432: **foo\nbar** -> strong spans newline
  @Test("Spec 432: strong spans newline")
  func spec432() {
    let input = "**foo\nbar**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    // Deterministic: exact children around soft line break
    #expect(sig(strong) == "strong[text(\"foo\"),line_break(soft),text(\"bar\")]")
    #expect(sig(para) == "paragraph[strong[text(\"foo\"),line_break(soft),text(\"bar\")]]")
  }

  // 433: __foo _bar_ baz__
  @Test("Spec 433: strong underscore containing emphasis")
  func spec433() {
    let input = "__foo _bar_ baz__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]")
  }

  // 434: __foo __bar__ baz__
  @Test("Spec 434: strong underscore containing strong underscore")
  func spec434() {
    let input = "__foo __bar__ baz__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo \"),strong[text(\"bar\")],text(\" baz\")]]")
  }

  // 435: ____foo__ bar__ -> nested strongs
  @Test("Spec 435: nested strongs with underscores")
  func spec435() {
    let input = "____foo__ bar__\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? StrongNode else {
      Issue.record("Expected outer StrongNode")
      return
    }
    #expect(outer.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[strong[strong[text(\"foo\")],text(\" bar\")]]")
  }

  // 436: **foo **bar**** -> strong containing strong
  @Test("Spec 436: strong containing strong")
  func spec436() {
    let input = "**foo **bar****\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? StrongNode else {
      Issue.record("Expected outer StrongNode")
      return
    }
    #expect(outer.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo \"),strong[text(\"bar\")]]]")
  }

  // 437: **foo *bar* baz**
  @Test("Spec 437: strong containing emphasis")
  func spec437() {
    let input = "**foo *bar* baz**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")],text(\" baz\")]]")
  }

  // 438: **foo*bar*baz**
  @Test("Spec 438: strong containing emphasis tight")
  func spec438() {
    let input = "**foo*bar*baz**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo\"),emphasis[text(\"bar\")],text(\"baz\")]]")
  }

  // 439: ***foo* bar** -> strong outer, inner em
  @Test("Spec 439: strong around emphasis then text")
  func spec439() {
    let input = "***foo* bar**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[strong[emphasis[text(\"foo\")],text(\" bar\")]]")
  }

  // 440: **foo *bar*** -> strong around emphasis at end
  @Test("Spec 440: strong around emphasis at end")
  func spec440() {
    let input = "**foo *bar***\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[strong[text(\"foo \"),emphasis[text(\"bar\")]]]")
  }

  // 441: **foo *bar **baz**\nbim* bop**
  @Test("Spec 441: strong containing emphasis and nested strong across lines")
  func spec441() {
    let input = "**foo *bar **baz**\nbim* bop**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.contains { $0 is EmphasisNode } == true)
    #expect(strong.children.contains { $0 is StrongNode } == true)
    // Deterministic: strong contains emphasis and strong across soft break
    #expect(
      sig(para)
        == "paragraph[strong[text(\"foo \"),emphasis[text(\"bar \")],strong[text(\"baz\")],line_break(soft),text(\"bim\"),emphasis[text(\" bop\")]]]"
    )
  }

  // 442: **foo [*bar*](/url)**
  @Test("Spec 442: strong around link containing emphasis")
  func spec442() {
    let input = "**foo [*bar*](/url)**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    let links = strong.children.compactMap { $0 as? LinkNode }
    #expect(links.count == 1)
    #expect(links[0].children.contains { $0 is EmphasisNode } == true)
    #expect(
      sig(para)
        == "paragraph[strong[text(\"foo \"),link(url:\"/url\",title:\"\")[emphasis[text(\"bar\")]]]"
    )
  }

  // 443: __ is not an empty emphasis -> literal
  @Test("Spec 443: literal '__ is not an empty emphasis'")
  func spec443() {
    let input = "__ is not an empty emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "__ is not an empty emphasis")
    #expect(sig(para) == "paragraph[text(\"__ is not an empty emphasis\")]")
  }

  // 444: ____ is not an empty strong emphasis -> literal
  @Test("Spec 444: literal '____ is not an empty strong emphasis'")
  func spec444() {
    let input = "____ is not an empty strong emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "____ is not an empty strong emphasis")
    #expect(sig(para) == "paragraph[text(\"____ is not an empty strong emphasis\")]")
  }

  // 445: foo *** -> literal trailing stars
  @Test("Spec 445: trailing stars literal")
  func spec445() {
    let input = "foo ***\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo ***")
    #expect(sig(para) == "paragraph[text(\"foo ***\")]")
  }

  // 446: foo *\** -> emphasis with escaped star
  @Test("Spec 446: emphasis of literal star")
  func spec446() {
    let input = "foo *\\**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "*")
    #expect(sig(para) == "paragraph[text(\"foo \"),emphasis[text(\"*\")]]")
  }

  // 447: foo *_* -> emphasis of underscore
  @Test("Spec 447: emphasis of underscore")
  func spec447() {
    let input = "foo *_*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "_")
    #expect(sig(para) == "paragraph[text(\"foo \"),emphasis[text(\"_\")]]")
  }

  // 448: foo ***** -> literal trailing stars
  @Test("Spec 448: literal five stars trailing")
  func spec448() {
    let input = "foo *****\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo *****")
    #expect(sig(para) == "paragraph[text(\"foo *****\")]")
  }

  // 449: foo **\*** -> strong of literal star
  @Test("Spec 449: strong of literal star")
  func spec449() {
    let input = "foo **\\***\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "*")
    #expect(sig(para) == "paragraph[text(\"foo \"),strong[text(\"*\")]]")
  }

  // 450: foo **_** -> strong of underscore
  @Test("Spec 450: strong of underscore")
  func spec450() {
    let input = "foo **_**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "_")
    #expect(sig(para) == "paragraph[text(\"foo \"),strong[text(\"_\")]]")
  }

  // 451: **foo* -> literal '*' then emphasis 'foo'
  @Test("Spec 451: literal star then emphasis")
  func spec451() {
    let input = "**foo*\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*")
    guard let em = para.children.last as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "foo")
    #expect(sig(para) == "paragraph[text(\"*\"),emphasis[text(\"foo\")]]")
  }

  // 452: *foo** -> emphasis 'foo' then literal '*'
  @Test("Spec 452: emphasis then literal star")
  func spec452() {
    let input = "*foo**\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at start")
      return
    }
    #expect(innerText(em) == "foo")
    #expect((para.children.last as? TextNode)?.content == "*")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\")],text(\"*\")]")
  }

  // 453: ***foo** -> literal '*' then strong 'foo'
  @Test("Spec 453: literal star then strong")
  func spec453() {
    let input = "***foo**\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*")
    guard let strong = para.children.last as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect(sig(para) == "paragraph[text(\"*\"),strong[text(\"foo\")]]")
  }

  // 454: ****foo* -> literal '***' then emphasis 'foo'
  @Test("Spec 454: three literal stars then emphasis")
  func spec454() {
    let input = "****foo*\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "***")
    guard let em = para.children.last as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "foo")
    #expect(sig(para) == "paragraph[text(\"***\"),emphasis[text(\"foo\")]]")
  }

  // 455: **foo*** -> strong 'foo' then literal '*'
  @Test("Spec 455: strong then literal star")
  func spec455() {
    let input = "**foo***\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode at start")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect((para.children.last as? TextNode)?.content == "*")
    #expect(sig(para) == "paragraph[strong[text(\"foo\")],text(\"*\")]")
  }

  // 456: *foo**** -> emphasis 'foo' then literal '***'
  @Test("Spec 456: emphasis then three literal stars")
  func spec456() {
    let input = "*foo****\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at start")
      return
    }
    #expect(innerText(em) == "foo")
    #expect((para.children.last as? TextNode)?.content == "***")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\")],text(\"***\")]")
  }

  // 457: foo ___ -> literal underscores
  @Test("Spec 457: literal triple underscores")
  func spec457() {
    let input = "foo ___\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo ___")
    #expect(sig(para) == "paragraph[text(\"foo ___\")]")
  }

  // 458: foo _\__ -> emphasis of underscore
  @Test("Spec 458: emphasis of underscore with escape")
  func spec458() {
    let input = "foo _\\__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "_")
    #expect(sig(para) == "paragraph[text(\"foo \"),emphasis[text(\"_\")]]")
  }

  // 459: foo _*_ -> emphasis of star
  @Test("Spec 459: emphasis of star between underscores")
  func spec459() {
    let input = "foo _*_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let em = para.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "*")
    #expect(sig(para) == "paragraph[text(\"foo \"),emphasis[text(\"*\")]]")
  }

  // 460: foo _____ -> literal five underscores
  @Test("Spec 460: literal five underscores")
  func spec460() {
    let input = "foo _____\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo _____")
    #expect(sig(para) == "paragraph[text(\"foo _____\")]")
  }

  // 461: foo __\___ -> strong of underscore with escape
  @Test("Spec 461: strong of underscore with escape")
  func spec461() {
    let input = "foo __\\___\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "_")
    #expect(sig(para) == "paragraph[text(\"foo \"),strong[text(\"_\")]]")
  }

  // 462: foo __*__ -> strong of star
  @Test("Spec 462: strong of star between underscores")
  func spec462() {
    let input = "foo __*__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 2)
    guard let strong = para.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "*")
    #expect(sig(para) == "paragraph[text(\"foo \"),strong[text(\"*\")]]")
  }

  // 463: __foo_ -> literal underscore then emphasis
  @Test("Spec 463: literal underscore then emphasis")
  func spec463() {
    let input = "__foo_\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "_")
    guard let em = para.children.last as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "foo")
    #expect(sig(para) == "paragraph[text(\"_\"),emphasis[text(\"foo\")]]")
  }

  // 464: _foo__ -> emphasis then literal underscore
  @Test("Spec 464: emphasis then literal underscore")
  func spec464() {
    let input = "_foo__\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at start")
      return
    }
    #expect(innerText(em) == "foo")
    #expect((para.children.last as? TextNode)?.content == "_")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\")],text(\"_\")]")
  }

  // 465: ___foo__ -> literal underscore then strong
  @Test("Spec 465: literal underscore then strong")
  func spec465() {
    let input = "___foo__\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "_")
    guard let strong = para.children.last as? StrongNode else {
      Issue.record("Expected StrongNode at end")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect(sig(para) == "paragraph[text(\"_\"),strong[text(\"foo\")]]")
  }

  // 466: ____foo_ -> literal '___' then emphasis
  @Test("Spec 466: triple literal underscores then emphasis")
  func spec466() {
    let input = "____foo_\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "___")
    guard let em = para.children.last as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at end")
      return
    }
    #expect(innerText(em) == "foo")
    #expect(sig(para) == "paragraph[text(\"___\"),emphasis[text(\"foo\")]]")
  }

  // 467: __foo___ -> strong then literal underscore
  @Test("Spec 467: strong then literal underscore")
  func spec467() {
    let input = "__foo___\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode at start")
      return
    }
    #expect(innerText(strong) == "foo")
    #expect((para.children.last as? TextNode)?.content == "_")
    #expect(sig(para) == "paragraph[strong[text(\"foo\")],text(\"_\")]")
  }

  // 468: _foo____ -> emphasis then literal '___'
  @Test("Spec 468: emphasis then triple literal underscores")
  func spec468() {
    let input = "_foo____\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at start")
      return
    }
    #expect(innerText(em) == "foo")
    #expect((para.children.last as? TextNode)?.content == "___")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo\")],text(\"___\")]")
  }

  // 469: **foo** -> simple strong
  @Test("Spec 469: simple strong")
  func spec469() {
    let input = "**foo**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo")
  }

  // 470: *_foo_* -> emphasis containing emphasis
  @Test("Spec 470: emphasis inside emphasis (asterisk outside, underscore inside)")
  func spec470() {
    let input = "*_foo_*\n"
    guard let para = firstParagraph(input) else { return }
    guard let emOuter = para.children.first as? EmphasisNode else {
      Issue.record("Expected outer EmphasisNode")
      return
    }
    #expect(emOuter.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[emphasis[emphasis[text(\"foo\")]]]")
  }

  // 471: __foo__ -> simple strong underscore
  @Test("Spec 471: simple strong underscore")
  func spec471() {
    let input = "__foo__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo")
  }

  // 472: _*foo*_ -> emphasis containing emphasis
  @Test("Spec 472: emphasis inside emphasis (underscore outside, asterisk inside)")
  func spec472() {
    let input = "_*foo*_\n"
    guard let para = firstParagraph(input) else { return }
    guard let emOuter = para.children.first as? EmphasisNode else {
      Issue.record("Expected outer EmphasisNode")
      return
    }
    #expect(emOuter.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[emphasis[emphasis[text(\"foo\")]]]")
  }

  // 473: ****foo**** -> double strong nesting
  @Test("Spec 473: double strong nesting with asterisks")
  func spec473() {
    let input = "****foo****\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? StrongNode else {
      Issue.record("Expected outer StrongNode")
      return
    }
    #expect(outer.children.contains { $0 is StrongNode } == true)
    #expect(innerText(outer) == "foo")
    #expect(sig(para) == "paragraph[strong[strong[text(\"foo\")]]]")
  }

  // 474: ____foo____ -> double strong nesting underscores
  @Test("Spec 474: double strong nesting with underscores")
  func spec474() {
    let input = "____foo____\n"
    guard let para = firstParagraph(input) else { return }
    guard let outer = para.children.first as? StrongNode else {
      Issue.record("Expected outer StrongNode")
      return
    }
    #expect(outer.children.contains { $0 is StrongNode } == true)
    #expect(innerText(outer) == "foo")
    #expect(sig(para) == "paragraph[strong[strong[text(\"foo\")]]]")
  }

  // 475: ******foo****** -> triple strong nesting
  @Test("Spec 475: triple strong nesting")
  func spec475() {
    let input = "******foo******\n"
    guard let para = firstParagraph(input) else { return }
    // At least two nested StrongNode levels
    let strongs = findNodes(in: para, ofType: StrongNode.self)
    #expect(strongs.count >= 2)
    // Deterministic: outer strong contains inner strong with text "foo"
    #expect(sig(para) == "paragraph[strong[strong[text(\"foo\")]]]")
  }

  // 476: ***foo*** -> emphasis around strong
  @Test("Spec 476: emphasis wrapping strong")
  func spec476() {
    let input = "***foo***\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[emphasis[strong[text(\"foo\")]]]")
  }

  // 477: _____foo_____ -> emphasis + double strong nesting
  @Test("Spec 477: emphasis wrapping double strong")
  func spec477() {
    let input = "_____foo_____\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(findNodes(in: em, ofType: StrongNode.self).count >= 2)
    #expect(sig(para) == "paragraph[emphasis[strong[strong[text(\"foo\")]]]]")
  }

  // 478: *foo _bar* baz_ -> unbalanced, per HTML emphasis ends before '_'
  @Test("Spec 478: unbalanced markers, partial emphasis")
  func spec478() {
    let input = "*foo _bar* baz_\n"
    guard let para = firstParagraph(input) else { return }
    // Expect Emphasis("foo _bar") then Text(" baz_")
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode first")
      return
    }
    #expect(innerText(em) == "foo _bar")
    #expect((para.children.last as? TextNode)?.content == " baz_")
    #expect(sig(para) == "paragraph[emphasis[text(\"foo _bar\")],text(\" baz_\")]")
  }

  // 479: *foo __bar *baz bim__ bam* -> unmatched inner * causes strong only
  @Test("Spec 479: emphasis contains strong with unmatched inner asterisk")
  func spec479() {
    let input = "*foo __bar *baz bim__ bam*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is StrongNode } == true)
    // Deterministic: emphasis contains strong with literal '*baz bim' inside due to unmatched asterisk
    #expect(
      sig(para)
        == "paragraph[emphasis[text(\"foo \"),strong[text(\"bar *baz bim\")],text(\" bam\")]]")
  }

  // 480: **foo **bar baz** -> unmatched opener before
  @Test("Spec 480: literal opener then strong")
  func spec480() {
    let input = "**foo **bar baz**\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "**foo ")
    #expect(para.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[text(\"**foo \"),strong[text(\"bar baz\")]]")
  }

  // 481: *foo *bar baz* -> literal opener then emphasis
  @Test("Spec 481: literal opener then emphasis")
  func spec481() {
    let input = "*foo *bar baz*\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*foo ")
    #expect(para.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[text(\"*foo \"),emphasis[text(\"bar baz\")]]")
  }

  // 482: *[bar*](/url) -> literal '*' then link
  @Test("Spec 482: literal star before link text")
  func spec482() {
    let input = "*[bar*](/url)\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*")
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect(sig(para) == "paragraph[text(\"*\"),link(url:\"/url\",title:\"\")[text(\"bar*\")]]")
  }

  // 483: _foo [bar_](/url) -> literal '_' then link
  @Test("Spec 483: literal underscore before link text")
  func spec483() {
    let input = "_foo [bar_](/url)\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "_foo ")
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect(sig(para) == "paragraph[text(\"_foo \"),link(url:\"/url\",title:\"\")[text(\"bar_\")]]")
  }

  // 484: *<img src=... title="*"/> -> literal leading '*'
  @Test("Spec 484: literal star before img tag")
  func spec484() {
    let input = "*<img src=\"foo\" title=\"*\"/>\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*<img src=\"foo\" title=\"*\"/>")
    #expect(sig(para) == "paragraph[text(\"*<img src=\\\"foo\\\" title=\\\"*\\\"/>\")]")
  }

  // 485: **<a href="**"> -> literal
  @Test("Spec 485: literal strong opener within HTML attribute context")
  func spec485() {
    let input = "**<a href=\"**\">\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "**<a href=\"**\">")
    #expect(sig(para) == "paragraph[text(\"**<a href=\\\"**\\\">\")]")
  }

  // 486: __<a href="__"> -> literal
  @Test("Spec 486: literal strong underscore opener within HTML attribute context")
  func spec486() {
    let input = "__<a href=\"__\">\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "__<a href=\"__\">")
    #expect(sig(para) == "paragraph[text(\"__<a href=\\\"__\\\">\")]")
  }

  // 487: *a `*`* -> emphasis around code span
  @Test("Spec 487: emphasis around inline code")
  func spec487() {
    let input = "*a `*`*\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    #expect(em.children.contains { $0 is InlineCodeNode } == true)
    let code = em.children.first { $0 is InlineCodeNode } as? InlineCodeNode
    #expect(code?.code == "*")
    #expect(sig(para) == "paragraph[emphasis[text(\"a \"),code(\"*\")]]")
  }

  // 488: _a `_`_ -> emphasis around code span with underscore
  @Test("Spec 488: underscore emphasis around inline code")
  func spec488() {
    let input = "_a `_`_\n"
    guard let para = firstParagraph(input) else { return }
    guard let em = para.children.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    let code = em.children.first { $0 is InlineCodeNode } as? InlineCodeNode
    #expect(code?.code == "_")
    #expect(sig(para) == "paragraph[emphasis[text(\"a \"),code(\"_\")]]")
  }

  // 489: **a<https://foo.bar/?q=**> -> autolink wins, leading '**a' literal
  @Test("Spec 489: autolink inside with literal strong opener before")
  func spec489() {
    let input = "**a<https://foo.bar/?q=**>\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect((para.children.first as? TextNode)?.content == "**a")
    let s = sig(para)
    #expect(
      s
        == "paragraph[text(\"**a\"),link(url:\"https://foo.bar/?q=**\",title:\"\")[text(\"https://foo.bar/?q=**\")]]"
    )
  }

  // 490: __a<https://foo.bar/?q=__> -> autolink wins, leading '__a' literal
  @Test("Spec 490: autolink with literal strong underscore opener before")
  func spec490() {
    let input = "__a<https://foo.bar/?q=__>\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect((para.children.first as? TextNode)?.content == "__a")
    let s = sig(para)
    #expect(
      s
        == "paragraph[text(\"__a\"),link(url:\"https://foo.bar/?q=__\",title:\"\")[text(\"https://foo.bar/?q=__\")]]"
    )
  }
}

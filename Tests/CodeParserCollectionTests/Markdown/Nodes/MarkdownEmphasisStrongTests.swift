import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("GFM - Emphasis and Strong Emphasis")
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

  // Example 360: Simple emphasis with asterisks
  @Test("Example 360: *foo bar* produces emphasis")
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

  // Example 361: Opening * followed by whitespace - not left-flanking
  @Test("Example 361: a * foo bar* - no emphasis due to space after opening delimiter")
  func spec361() {
    let input = "a * foo bar*\n"
    guard let para = firstParagraph(input) else { return }
    let ems = para.children.compactMap { $0 as? EmphasisNode }
    let strs = para.children.compactMap { $0 as? StrongNode }
    #expect(ems.isEmpty && strs.isEmpty)
    #expect(sig(para) == "paragraph[text(\"a * foo bar*\")]")
  }

  // Example 362: Opening * preceded by alphanumeric, followed by punctuation - not left-flanking
  @Test("Example 362: a*\"foo\"* - no emphasis, delimiter not left-flanking")
  func spec362() {
    let input = "a*\"foo\"*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "a*\"foo\"*")
    #expect(sig(para) == "paragraph[text(\"a*\\\"foo\\\"*\")]")
  }

  // 363: * a * (NBSP) -> no emphasis
  @Test("Example 363: Unicode nonbreaking spaces count as whitespace, too")
  func spec363() {
    let input = "* a *\n"  // NBSP characters
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "* a *")
    #expect(sig(para) == "paragraph[text(\"* a *\")]")
  }

  // Custom E1: Additional test for currency symbols - not in official spec
  @Test("Custom E1: *$*alpha / *£*bravo / *€*charlie - no emphasis with currency symbols")
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

  // Example 364: Intraword emphasis with * is permitted
  @Test("Example 364: foo*bar* - intraword emphasis allowed with asterisks")
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

  // Example 365: Numeric intraword emphasis
  @Test("Example 365: 5*6*78 - emphasis allowed between numbers")
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

  // Example 366: Simple emphasis with underscores (Rule 2)
  @Test("Example 366: _foo bar_ produces emphasis")
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

  // Example 367: Opening _ followed by whitespace - not left-flanking
  @Test("Example 367: _ foo bar_ - no emphasis due to space after opening delimiter")
  func spec367() {
    let input = "_ foo bar_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "_ foo bar_")
    #expect(sig(para) == "paragraph[text(\"_ foo bar_\")]")
  }

  // Example 368: Opening _ preceded by alphanumeric, followed by punctuation - not left-flanking
  @Test("Example 368: a_\"foo\"_ - no emphasis, delimiter not left-flanking")
  func spec368() {
    let input = "a_\"foo\"_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "a_\"foo\"_")
    #expect(sig(para) == "paragraph[text(\"a_\\\"foo\\\"_\")]")
  }

  // Example 369: Underscore intraword emphasis is forbidden
  @Test("Example 369: foo_bar_ - no emphasis, underscores not allowed inside words")
  func spec369() {
    let input = "foo_bar_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "foo_bar_")
    #expect(sig(para) == "paragraph[text(\"foo_bar_\")]")
  }

  // Example 370: Numeric underscore emphasis forbidden
  @Test("Example 370: 5_6_78 - no emphasis with underscores between numbers")
  func spec370() {
    let input = "5_6_78\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "5_6_78")
    #expect(sig(para) == "paragraph[text(\"5_6_78\")]")
  }

  // 371: пристаням_стремятся_ -> no emphasis
  @Test("Example 371: Emphasis with _ is not allowed inside words")
  func spec371() {
    let input = "пристаням_стремятся_\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "пристаням_стремятся_")
    #expect(sig(para) == "paragraph[text(\"пристаням_стремятся_\")]")
  }

  // 372: aa_"bb"_cc -> no emphasis
  @Test("Example 372: _ does not generate emphasis, because the first delimiter run is right-flanking and the second left-flanking")
  func spec372() {
    let input = "aa_\"bb\"_cc\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "aa_\"bb\"_cc")
    #expect(sig(para) == "paragraph[text(\"aa_\\\"bb\\\"_cc\")]")
  }

  // 373: foo-_(bar)_ -> emphasis with underscores
  @Test("Example 373: emphasis, even though the opening delimiter is both left- and right-flanking, because it is preceded by punctuation")
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
  @Test("Example 374: unmatched markers across types -> no emphasis")
  func spec374() {
    let input = "_foo*\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "_foo*")
    #expect(sig(para) == "paragraph[text(\"_foo*\")]")
  }

  // 375: *foo bar * -> no emphasis due to space before closer
  @Test("Example 375: trailing space before '*' closer prevents emphasis")
  func spec375() {
    let input = "*foo bar *\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "*foo bar *")
    #expect(sig(para) == "paragraph[text(\"*foo bar *\")]")
  }

  // 376: *foo bar\n* -> no emphasis across line
  @Test("Example 376: newline breaks emphasis; remains literal with line break")
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
  @Test("Example 377: not emphasis, because the second * is preceded by punctuation and followed by an alphanumeric (hence it is not part of a right-flanking delimiter run)")
  func spec377() {
    let input = "*(*foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect((para.children.first as? TextNode)?.content == "*(*foo)")
    #expect(sig(para) == "paragraph[text(\"*(*foo)\")]")
  }

  // 378: *(*foo*)* -> nested emphasis
  @Test("Example 378: nested emphasis with asterisks")
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
  @Test("Example 379: Intraword emphasis with * is allowed")
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
  @Test("Example 380: trailing space before underscore closer -> no emphasis")
  func spec380() {
    let input = "_foo bar _\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_foo bar _\")]")
  }

  // 381: _(_foo) -> no emphasis
  @Test("Example 381: not emphasis, because the second _ is preceded by punctuation and followed by an alphanumeric")
  func spec381() {
    let input = "_(_foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_(_foo)\")]")
  }

  // 382: _(_foo_)_ -> nested emphasis
  @Test("Example 382: nested emphasis with underscores")
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
  @Test("Example 383: intraword underscore -> no emphasis")
  func spec383() {
    let input = "_foo_bar\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_foo_bar\")]")
  }

  // 384: _пристаням_стремятся -> no emphasis
  @Test("Example 384: intraword underscore -> no emphasis")
  func spec384() {
    let input = "_пристаням_стремятся\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is EmphasisNode } == false)
    #expect(sig(para) == "paragraph[text(\"_пристаням_стремятся\")]")
  }

  // 385: _foo_bar_baz_ -> emphasis of whole
  @Test("Example 385: Intraword emphasis is disallowed for _")
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
  @Test("Example 386: emphasis, even though the closing delimiter is both left- and right-flanking, because it is followed by punctuation")
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

  // Example 387: Simple strong emphasis with ** (Rule 5)
  @Test("Example 387: **foo bar** produces strong emphasis")
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

  // Example 388: Opening ** followed by whitespace - not left-flanking
  @Test("Example 388: ** foo bar** - no strong emphasis due to space after opener")
  func spec388() {
    let input = "** foo bar**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"** foo bar**\")]")
  }

  // Example 389: Opening ** preceded by alphanumeric, followed by punctuation - not left-flanking
  @Test("Example 389: a**\"foo\"** - no strong emphasis, delimiter not left-flanking")
  func spec389() {
    let input = "a**\"foo\"**\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"a**\\\"foo\\\"**\")]")
  }

  // 390: foo**bar** -> strong after text
  @Test("Example 390: trailing strong after text")
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

  // Example 391: Simple strong emphasis with __ (Rule 6)
  @Test("Example 391: __foo bar__ produces strong emphasis")
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

  // Example 392: Opening __ followed by whitespace - not left-flanking
  @Test("Example 392: __ foo bar__ - no strong emphasis due to space after opener")
  func spec392() {
    let input = "__ foo bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__ foo bar__\")]")
  }

  // 393: __\nfoo bar__ -> no strong across line
  @Test("Example 393: newline breaks strong")
  func spec393() {
    let input = "__\nfoo bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__\\nfoo bar__\")]")
  }

  // 394: a__"foo"__ -> no strong
  @Test("Example 394: punctuation adjacent underscore strong -> no strong")
  func spec394() {
    let input = "a__\"foo\"__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"a__\\\"foo\\\"__\")]")
  }

  // 395: foo__bar__ -> no strong
  @Test("Example 395: literal double underscores intraword -> no strong")
  func spec395() {
    let input = "foo__bar__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"foo__bar__\")]")
  }

  // 396: 5__6__78 -> no strong
  @Test("Example 396: digits with double underscores -> no strong")
  func spec396() {
    let input = "5__6__78\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"5__6__78\")]")
  }

  // 397: пристаням__стремятся__ -> no strong
  @Test("Example 397: non-Latin intraword double underscore -> no strong")
  func spec397() {
    let input = "пристаням__стремятся__\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"пристаням__стремятся__\")]")
  }

  // 398: __foo, __bar__, baz__ -> nested strong
  @Test("Example 398: nested strong inside strong")
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
  @Test("Example 399: strong around parenthesized text")
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
  @Test("Example 400: trailing space before closer prevents strong")
  func spec400() {
    let input = "**foo bar **\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"**foo bar **\")]")
  }

  // 401: **(**foo) -> no strong
  @Test("Example 401: opener immediately followed by ( -> no strong")
  func spec401() {
    let input = "**(**foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"**(**foo)\")]")
  }

  // 402: *(**foo**)* -> emphasis containing strong
  @Test("Example 402: emphasis around strong")
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

  // Example 403: Strong emphasis spanning lines with nested emphasis
  @Test("Example 403: **Gomphocarpus (*...*, syn.\\n*...*)**  - strong with nested emphasis across line break")
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
  @Test("Example 404: strong containing emphasis")
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
  @Test("Example 405: strong followed by text")
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
  @Test("Example 406: trailing space before underscore closer -> no strong")
  func spec406() {
    let input = "__foo bar __\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__foo bar __\")]")
  }

  // 407: __(__foo) -> no strong
  @Test("Example 407: underscore strong opener followed by ( -> no strong")
  func spec407() {
    let input = "__(__foo)\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__(__foo)\")]")
  }

  // 408: _(__foo__)_ -> emphasis containing strong
  @Test("Example 408: underscore emphasis around strong")
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
  @Test("Example 409: strong then literal 'bar'")
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
  @Test("Example 410: non-Latin intraword double underscore -> no strong")
  func spec410() {
    let input = "__пристаням__стремятся\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.contains { $0 is StrongNode } == false)
    #expect(sig(para) == "paragraph[text(\"__пристаням__стремятся\")]")
  }

  // 411: __foo__bar__baz__ -> strong around whole
  @Test("Example 411: outer strong with intraword underscores inside")
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
  @Test("Example 412: strong with trailing period")
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
  @Test("Example 413: emphasis around link")
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
  @Test("Example 414: emphasis spans newline")
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
  @Test("Example 415: emphasis containing strong inside")
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
  @Test("Example 416: emphasis containing emphasis")
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
  @Test("Example 417: emphasis nested then outer emphasis")
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
  @Test("Example 418: emphasis nesting with closing strong")
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
  @Test("Example 419: emphasis containing strong in middle")
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
  @Test("Example 420: emphasis with strong inside contiguous text")
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
  @Test("Example 421: unmatched strong closer inside emphasis")
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
  @Test("Example 422: emphasis around strong then text")
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
  @Test("Example 423: emphasis containing strong at end")
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
  @Test("Example 424: emphasis containing strong tightly")
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
  @Test("Example 425: text then emphasis(strong) then text")
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
  @Test("Example 426: multiple strong nestings then leftover stars")
  func spec426() {
    let input = "foo******bar*********baz\n"
    guard let para = firstParagraph(input) else { return }
    // At least one Strong inside, and trailing text contains ***baz per HTML
    #expect(para.children.contains { $0 is StrongNode } == true)
    // Deterministic checks: first child is text "foo", last child is text ending with "baz"
    #expect((para.children.first as? TextNode)?.content == "foo")
    #expect((para.children.last as? TextNode)?.content == "baz")
  }

  // 427: Complex nested emphasis and strong emphasis with proper precedence
  @Test("Example 427: nested emphasis inside strong emphasis inside emphasis")
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
  @Test("Example 428: emphasis around link that contains emphasis")
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
  @Test("Example 429: ** is not an empty emphasis - literal text")
  func spec429() {
    let input = "** is not an empty emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "** is not an empty emphasis")
    #expect(sig(para) == "paragraph[text(\"** is not an empty emphasis\")]")
  }

  // 430: **** is not an empty strong emphasis -> literal
  @Test("Example 430: **** is not an empty strong emphasis - literal text")
  func spec430() {
    let input = "**** is not an empty strong emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "**** is not an empty strong emphasis")
    #expect(sig(para) == "paragraph[text(\"**** is not an empty strong emphasis\")]")
  }

  // 431: **foo [bar](/url)** -> strong around link
  @Test("Example 431: strong around link")
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
  @Test("Example 432: strong spans newline")
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
  @Test("Example 433: strong underscore containing emphasis")
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
  @Test("Example 434: strong underscore containing strong underscore")
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
  @Test("Example 435: nested strongs with underscores")
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
  @Test("Example 436: strong containing strong")
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
  @Test("Example 437: strong containing emphasis")
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
  @Test("Example 438: strong containing emphasis tight")
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
  @Test("Example 439: strong around emphasis then text")
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
  @Test("Example 440: strong around emphasis at end")
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
  @Test("Example 441: strong containing emphasis and nested strong across lines")
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
  @Test("Example 442: strong around link containing emphasis")
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
  @Test("Example 443: __ is not an empty emphasis - literal text")
  func spec443() {
    let input = "__ is not an empty emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "__ is not an empty emphasis")
    #expect(sig(para) == "paragraph[text(\"__ is not an empty emphasis\")]")
  }

  // 444: ____ is not an empty strong emphasis -> literal
  @Test("Example 444: ____ is not an empty strong emphasis - literal text")
  func spec444() {
    let input = "____ is not an empty strong emphasis\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "____ is not an empty strong emphasis")
    #expect(sig(para) == "paragraph[text(\"____ is not an empty strong emphasis\")]")
  }

  // 445: foo *** -> literal trailing stars
  @Test("Example 445: trailing stars literal")
  func spec445() {
    let input = "foo ***\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo ***")
    #expect(sig(para) == "paragraph[text(\"foo ***\")]")
  }

  // 446: foo *\** -> emphasis with escaped star
  @Test("Example 446: emphasis of literal star")
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
  @Test("Example 447: emphasis of underscore")
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
  @Test("Example 448: literal five stars trailing")
  func spec448() {
    let input = "foo *****\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo *****")
    #expect(sig(para) == "paragraph[text(\"foo *****\")]")
  }

  // 449: foo **\*** -> strong of literal star
  @Test("Example 449: strong of literal star")
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
  @Test("Example 450: strong of underscore")
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
  @Test("Example 451: literal star then emphasis")
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
  @Test("Example 452: emphasis then literal star")
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
  @Test("Example 453: literal star then strong")
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
  @Test("Example 454: three literal stars then emphasis")
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
  @Test("Example 455: strong then literal star")
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
  @Test("Example 456: emphasis then three literal stars")
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
  @Test("Example 457: literal triple underscores")
  func spec457() {
    let input = "foo ___\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo ___")
    #expect(sig(para) == "paragraph[text(\"foo ___\")]")
  }

  // 458: foo _\__ -> emphasis of underscore
  @Test("Example 458: emphasis of underscore with escape")
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
  @Test("Example 459: emphasis of star between underscores")
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
  @Test("Example 460: literal five underscores")
  func spec460() {
    let input = "foo _____\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "foo _____")
    #expect(sig(para) == "paragraph[text(\"foo _____\")]")
  }

  // 461: foo __\___ -> strong of underscore with escape
  @Test("Example 461: strong of underscore with escape")
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
  @Test("Example 462: strong of star between underscores")
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
  @Test("Example 463: literal underscore then emphasis")
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
  @Test("Example 464: emphasis then literal underscore")
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
  @Test("Example 465: literal underscore then strong")
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
  @Test("Example 466: triple literal underscores then emphasis")
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
  @Test("Example 467: strong then literal underscore")
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
  @Test("Example 468: emphasis then triple literal underscores")
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

  // Example 469: Nested emphasis demonstration (Rule 13)
  @Test("Example 469: **foo** - simple strong emphasis")
  func spec469() {
    let input = "**foo**\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo")
  }

  // Example 470: Different delimiters for nested emphasis (Rule 13)
  @Test("Example 470: *_foo_* - asterisk emphasis around underscore emphasis")
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
  @Test("Example 471: simple strong underscore")
  func spec471() {
    let input = "__foo__\n"
    guard let para = firstParagraph(input) else { return }
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(innerText(strong) == "foo")
  }

  // Example 472: Different delimiters for nested emphasis (Rule 13)
  @Test("Example 472: _*foo*_ - underscore emphasis around asterisk emphasis")
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

  // Example 473: Strong emphasis can nest within strong emphasis
  @Test("Example 473: ****foo**** - double strong nesting with same delimiters")
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

  // Example 474: Strong emphasis can nest within strong emphasis
  @Test("Example 474: ____foo____ - double strong nesting with underscores")
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
  @Test("Example 475: triple strong nesting")
  func spec475() {
    let input = "******foo******\n"
    guard let para = firstParagraph(input) else { return }
    // At least two nested StrongNode levels
    let strongs = findNodes(in: para, ofType: StrongNode.self)
    #expect(strongs.count >= 2)
    // Deterministic: outer strong contains inner strong with text "foo"
    #expect(sig(para) == "paragraph[strong[strong[text(\"foo\")]]]")
  }

  // Example 476: Triple asterisk parsing (Rule 14)
  @Test("Example 476: ***foo*** - emphasis wrapping strong emphasis")
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
  @Test("Example 477: emphasis wrapping double strong")
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

  // Example 478: Overlapping emphasis spans (Rule 15 precedence)
  @Test("Example 478: *foo _bar* baz_ - first emphasis takes precedence")
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
  @Test("Example 479: emphasis contains strong with unmatched inner asterisk")
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

  // Example 480: Shorter emphasis span precedence (Rule 16)
  @Test("Example 480: **foo **bar baz** - shorter span takes precedence")
  func spec480() {
    let input = "**foo **bar baz**\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "**foo ")
    #expect(para.children.contains { $0 is StrongNode } == true)
    #expect(sig(para) == "paragraph[text(\"**foo \"),strong[text(\"bar baz\")]]")
  }

  // 481: *foo *bar baz* -> literal opener then emphasis
  @Test("Example 481: literal opener then emphasis")
  func spec481() {
    let input = "*foo *bar baz*\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*foo ")
    #expect(para.children.contains { $0 is EmphasisNode } == true)
    #expect(sig(para) == "paragraph[text(\"*foo \"),emphasis[text(\"bar baz\")]]")
  }

  // 482: *[bar*](/url) -> literal '*' then link
  @Test("Example 482: literal star before link text")
  func spec482() {
    let input = "*[bar*](/url)\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*")
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect(sig(para) == "paragraph[text(\"*\"),link(url:\"/url\",title:\"\")[text(\"bar*\")]]")
  }

  // 483: _foo [bar_](/url) -> literal '_' then link
  @Test("Example 483: literal underscore before link text")
  func spec483() {
    let input = "_foo [bar_](/url)\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "_foo ")
    #expect(para.children.contains { $0 is LinkNode } == true)
    #expect(sig(para) == "paragraph[text(\"_foo \"),link(url:\"/url\",title:\"\")[text(\"bar_\")]]")
  }

  // 484: *<img src=... title="*"/> -> literal leading '*'
  @Test("Example 484: literal star before img tag")
  func spec484() {
    let input = "*<img src=\"foo\" title=\"*\"/>\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "*<img src=\"foo\" title=\"*\"/>")
    #expect(sig(para) == "paragraph[text(\"*<img src=\\\"foo\\\" title=\\\"*\\\"/>\")]")
  }

  // 485: **<a href="**"> -> literal
  @Test("Example 485: literal strong opener within HTML attribute context")
  func spec485() {
    let input = "**<a href=\"**\">\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "**<a href=\"**\">")
    #expect(sig(para) == "paragraph[text(\"**<a href=\\\"**\\\">\")]")
  }

  // 486: __<a href="__"> -> literal
  @Test("Example 486: literal strong underscore opener within HTML attribute context")
  func spec486() {
    let input = "__<a href=\"__\">\n"
    guard let para = firstParagraph(input) else { return }
    #expect((para.children.first as? TextNode)?.content == "__<a href=\"__\">")
    #expect(sig(para) == "paragraph[text(\"__<a href=\\\"__\\\">\")]")
  }

  // Example 487: Code spans have higher precedence (Rule 17)
  @Test("Example 487: *a `*`* - emphasis around inline code span")
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
  @Test("Example 488: underscore emphasis around inline code")
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

  // Example 489: Autolinks have higher precedence (Rule 17)
  @Test("Example 489: **a<https://foo.bar/?q=**> - autolink breaks strong emphasis")
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

  // Example 490: Final emphasis example - autolinks break underscore strong
  @Test("Example 490: __a<https://foo.bar/?q=__> - autolink breaks strong emphasis")
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

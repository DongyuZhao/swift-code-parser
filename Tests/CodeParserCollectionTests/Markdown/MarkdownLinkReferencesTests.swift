import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Link Reference Definitions (Strict)")
struct MarkdownLinkReferencesBlocksTests {
  private let h = MarkdownTestHarness()

  // Helpers
  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
  }

  private func inlineChildrenIgnoringBreaks(_ p: ParagraphNode) -> [CodeNode<MarkdownNodeElement>] {
    p.children.filter { $0.element != .lineBreak }
  }
  // Using shared childrenTypes/sig from Tests/.../Utils/TestUtils.swift

  // 161
  @Test("Spec 161: Basic reference definition then use")
  func spec161() {
    let input = "[foo]: /url \"title\"\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(p.children.count == 1)
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/url")
    #expect(link.title == "title")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"title\")[text(\"foo\")]]]")
  }

  // 162
  @Test("Spec 162: Definition spread across indented lines")
  func spec162() {
    let input = "   [foo]: \n      /url  \n           'the title'  \n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/url")
    #expect(link.title == "the title")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/url\",title:\"the title\")[text(\"foo\")]]]")
  }

  // 163
  @Test("Spec 163: Escapes in label and parens in title")
  func spec163() {
    let input = "[Foo*bar\\]]:my_(url) 'title (with parens)'\n\n[Foo*bar\\]]\n"
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
    #expect(link.url == "my_(url)")
    #expect(link.title == "title (with parens)")
    #expect((link.children.first as? TextNode)?.content == "Foo*bar]")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"my_(url)\",title:\"title (with parens)\")[text(\"Foo*bar]\")]]]"
    )
  }

  // 164
  @Test("Spec 164: Angle-bracketed destination with spaces encodes to %20, title on next line")
  func spec164() {
    let input = "[Foo bar]:\n<my url>\n'title'\n\n[Foo bar]\n"
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
    #expect(link.url == "my%20url")
    #expect(link.title == "title")
    #expect((link.children.first as? TextNode)?.content == "Foo bar")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"my%20url\",title:\"title\")[text(\"Foo bar\")]]]")
  }

  // 165
  @Test("Spec 165: Multiline title in single quotes is preserved with newlines")
  func spec165() {
    let input = "[foo]: /url 'title\nline1\nline2\n'\n\n[foo]\n"
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
    #expect(link.url == "/url")
    #expect(link.title == "\ntitle\nline1\nline2\n")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/url\",title:\"\\ntitle\\nline1\\nline2\\n\")[text(\"foo\")]]]"
    )
  }

  // 166
  @Test("Spec 166: Blank line breaks title -> literal paragraphs")
  func spec166() {
    let input = "[foo]: /url 'title\n\nwith blank line'\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode,
      let p3 = result.root.children[2] as? ParagraphNode
    else {
      Issue.record("Expected three paragraphs")
      return
    }
    #expect(innerText(p1) == "[foo]: /url 'title")
    #expect(innerText(p2) == "with blank line'")
    #expect(innerText(p3) == "[foo]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"[foo]: /url 'title\")],paragraph[text(\"with blank line'\")],paragraph[text(\"[foo]\")]]"
    )
  }

  // 167
  @Test("Spec 167: Destination on next line without title")
  func spec167() {
    let input = "[foo]:\n/url\n\n[foo]\n"
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
    #expect(link.url == "/url")
    #expect(link.title.isEmpty)
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]]]")
  }

  // 168
  @Test("Spec 168: Missing destination -> literal paragraphs")
  func spec168() {
    let input = "[foo]:\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    #expect(innerText(p1) == "[foo]:")
    #expect(innerText(p2) == "[foo]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"[foo]:\")],paragraph[text(\"[foo]\")]]")
  }

  // 169
  @Test("Spec 169: Empty destination <> becomes empty href")
  func spec169() {
    let input = "[foo]: <>\n\n[foo]\n"
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
    #expect(link.url == "")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(sig(result.root) == "document[paragraph[link(url:\"\",title:\"\")[text(\"foo\")]]]")
  }

  // 170
  @Test("Spec 170: Invalid destination syntax -> literal paragraphs")
  func spec170() {
    let input = "[foo]: <bar>(baz)\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p1 = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    #expect(innerText(p1) == "[foo]: <bar>(baz)")
    #expect(innerText(p2) == "[foo]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"[foo]: <bar>(baz)\")],paragraph[text(\"[foo]\")]]")
  }

  // 171
  @Test("Spec 171: Escapes in destination and title are normalized")
  func spec171() {
    let input = "[foo]: /url\\bar\\*baz \"foo\\\"bar\\\\baz\"\n\n[foo]\n"
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
    #expect(link.url == "/url%5Cbar*baz")
    #expect(link.title == "foo\"bar\\baz")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/url%5Cbar*baz\",title:\"foo\\\"bar\\\\baz\")[text(\"foo\")]]]"
    )
  }

  // 172
  @Test("Spec 172: Definition after use still resolves")
  func spec172() {
    let input = "[foo]\n\n[foo]: url\n"
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
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(sig(result.root) == "document[paragraph[link(url:\"url\",title:\"\")[text(\"foo\")]]]")
  }

  // 173
  @Test("Spec 173: First definition wins on duplicates")
  func spec173() {
    let input = "[foo]\n\n[foo]: first\n[foo]: second\n"
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
    #expect(link.url == "first")
    #expect(
      sig(result.root) == "document[paragraph[link(url:\"first\",title:\"\")[text(\"foo\")]]]")
  }

  // 174
  @Test("Spec 174: Label matching is case-insensitive")
  func spec174() {
    let input = "[FOO]: /url\n\n[Foo]\n"
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
    #expect(link.url == "/url")
    #expect((link.children.first as? TextNode)?.content == "Foo")
    #expect(sig(result.root) == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"Foo\")]]]")
  }

  // 175
  @Test("Spec 175: Case-insensitive labels with Unicode")
  func spec175() {
    let input = "[ΑΓΩ]: /φου\n\n[αγω]\n"
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
    #expect(link.url == "/%CF%86%CE%BF%CF%85")
    #expect((link.children.first as? TextNode)?.content == "αγω")
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/%CF%86%CE%BF%CF%85\",title:\"\")[text(\"αγω\")]]]")
  }

  // 176
  @Test("Spec 176: Definition without use produces no output")
  func spec176() {
    let input = "[foo]: /url\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.isEmpty)
    #expect(sig(result.root) == "document")
  }

  // 177
  @Test("Spec 177: Newlines inside label -> not a definition")
  func spec177() {
    let input = "[\nfoo\n]: /url\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "bar")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"bar\")]]")
  }

  // 178
  @Test("Spec 178: Trailing garbage after title -> literal paragraph")
  func spec178() {
    let input = "[foo]: /url \"title\" ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[foo]: /url \"title\" ok")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"[foo]: /url \\\"title\\\" ok\")]]")
  }

  // 179
  @Test("Spec 179: Following line not part of definition -> becomes paragraph")
  func spec179() {
    let input = "[foo]: /url\n\"title\" ok\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "\"title\" ok")
    #expect(sig(result.root) == "document[paragraph[text(\"\\\"title\\\" ok\")]]")
  }

  // 180
  @Test("Spec 180: Indented (4 spaces) -> code block, definition literal")
  func spec180() {
    let input = "    [foo]: /url \"title\"\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "[foo]: /url \"title\"")
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[foo]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(
      sig(result.root)
        == "document[code_block(\"[foo]: /url \\\"title\\\"\"),paragraph[text(\"[foo]\")]]")
  }

  // 181
  @Test("Spec 181: Fenced code block -> definition literal; use not resolved")
  func spec181() {
    let input = "```\n[foo]: /url\n```\n\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "[foo]: /url")
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "[foo]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(sig(result.root) == "document[code_block(\"[foo]: /url\"),paragraph[text(\"[foo]\")]]")
  }

  // 182
  @Test("Spec 182: No blank line before -> not a definition")
  func spec182() {
    let input = "Foo\n[bar]: /baz\n\n[bar]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let _ = result.root.children[0] as? ParagraphNode,
      let p2 = result.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two paragraphs")
      return
    }
    #expect(innerText(p2) == "[bar]")
    #expect(findNodes(in: result.root, ofType: LinkNode.self).isEmpty)
    #expect(childrenTypes(result.root) == [.paragraph, .paragraph])
    #expect(sig(p2) == "paragraph[text(\"[bar]\")]")
  }

  // 183
  @Test("Spec 183: Definition can appear after heading; resolves link in heading")
  func spec183() {
    let input = "# [Foo]\n[foo]: /url\n> bar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let h1 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    guard let link = findNodes(in: h1, ofType: LinkNode.self).first else {
      Issue.record("Expected Link in heading")
      return
    }
    #expect(link.url == "/url")
    #expect((link.children.first as? TextNode)?.content == "Foo")
    guard let bq = result.root.children.last as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let bp = bq.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph in blockquote")
      return
    }
    #expect(innerText(bp) == "bar")
    #expect(
      sig(result.root)
        == "document[heading(level:1)[link(url:\"/url\",title:\"\")[text(\"Foo\")]],blockquote[paragraph[text(\"bar\")]]]"
    )
  }

  // 184
  @Test("Spec 184: Setext heading recognized; following link resolves")
  func spec184() {
    let input = "[foo]: /url\nbar\n===\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let h1 = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(h1.level == 1)
    let h1Text = findNodes(in: h1, ofType: TextNode.self).map { $0.content }.joined()
    #expect(h1Text == "bar")
    guard let p = result.root.children.last as? ParagraphNode,
      let link = p.children.first as? LinkNode
    else {
      Issue.record("Expected ParagraphNode with LinkNode")
      return
    }
    #expect(link.url == "/url")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[heading(level:1)[text(\"bar\")],paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]]]"
    )
  }

  // 185
  @Test("Spec 185: Setext marker not heading -> stays text before link")
  func spec185() {
    let input = "[foo]: /url\n===\n[foo]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // inline order (ignoring line breaks): Text("===") then Link("foo")
    let inlines = inlineChildrenIgnoringBreaks(p)
    #expect(inlines.count == 2)
    #expect((inlines[0] as? TextNode)?.content == "===")
    guard let link = inlines[1] as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/url")
    #expect((link.children.first as? TextNode)?.content == "foo")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"===\"),line_break(soft),link(url:\"/url\",title:\"\")[text(\"foo\")]]]"
    )
  }

  // 186
  @Test("Spec 186: Multiple definitions and uses; titles and order preserved")
  func spec186() {
    let input =
      "[foo]: /foo-url \"foo\"\n[bar]: /bar-url\n  \"bar\"\n[baz]: /baz-url\n\n[foo],\n[bar],\n[baz]\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Extract inline sequence ignoring breaks
    let inlines = inlineChildrenIgnoringBreaks(p)
    // Expect pattern: Link(foo), Text(","), Link(bar), Text(","), Link(baz)
    #expect(inlines.count == 5)
    guard let l1 = inlines[0] as? LinkNode,
      let t1 = inlines[1] as? TextNode,
      let l2 = inlines[2] as? LinkNode,
      let t2 = inlines[3] as? TextNode,
      let l3 = inlines[4] as? LinkNode
    else {
      Issue.record("Unexpected inline sequence for spec217")
      return
    }
    #expect(l1.url == "/foo-url")
    #expect(l1.title == "foo")
    #expect((l1.children.first as? TextNode)?.content == "foo")
    #expect(t1.content == ",")
    #expect(l2.url == "/bar-url")
    #expect(l2.title == "bar")
    #expect((l2.children.first as? TextNode)?.content == "bar")
    #expect(t2.content == ",")
    #expect(l3.url == "/baz-url")
    #expect(l3.title.isEmpty)
    #expect((l3.children.first as? TextNode)?.content == "baz")
    // Include line breaks explicitly in signature between items
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/foo-url\",title:\"foo\")[text(\"foo\")],text(\",\"),line_break(soft),link(url:\"/bar-url\",title:\"bar\")[text(\"bar\")],text(\",\"),line_break(soft),link(url:\"/baz-url\",title:\"\")[text(\"baz\")]]]"
    )
  }

  // 187
  @Test("Spec 187: Definition inside blockquote resolves previous use; bq renders empty")
  func spec187() {
    let input = "[foo]\n\n> [foo]: /url\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected first ParagraphNode")
      return
    }
    guard let link = p.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "/url")
    guard let bq = result.root.children.last as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(bq.children.isEmpty)
    #expect(
      sig(result.root)
        == "document[paragraph[link(url:\"/url\",title:\"\")[text(\"foo\")]],blockquote]")
  }

  // 188
  @Test("Spec 188: Lone definition produces no output")
  func spec188() {
    let input = "[foo]: /url\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.isEmpty)
    #expect(sig(result.root) == "document")
  }
}

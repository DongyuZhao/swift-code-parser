import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Code Spans")
struct MarkdownCodeSpansTests {
  private let h = MarkdownTestHarness()

  // Spec 307: code span then literal trailing backtick as text
  @Test("Spec 307: `hi`lo` -> InlineCode 'hi' + Text 'lo`'")
  func spec307() {
    let input = "`hi`lo`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? InlineCodeNode)?.code == "hi")
    #expect((para.children[1] as? TextNode)?.content == "lo`")
    #expect(sig(result.root) == "document[paragraph[code(\"hi\"),text(\"lo`\")]]")
  }

  // Spec 338: simple code span
  @Test("Spec 338: simple code span `foo`")
  func spec338() {
    let input = "`foo`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo")
    #expect(sig(result.root) == "document[paragraph[code(\"foo\")]]")
  }

  // Spec 339: backticks inside span when fenced by double backticks
  @Test("Spec 339: `` foo ` bar `` -> code 'foo ` bar'")
  func spec339() {
    let input = "`` foo ` bar ``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo ` bar")
    #expect(sig(result.root) == "document[paragraph[code(\"foo ` bar\")]]")
  }

  // Spec 340: content is two backticks
  @Test("Spec 340: ` `` ` -> code '``'")
  func spec340() {
    let input = "` `` `\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "``")
    #expect(sig(result.root) == "document[paragraph[code(\"``\")]]")
  }

  // Spec 341: preserves one leading/trailing space when surrounded by two spaces inside
  @Test("Spec 341: `  ``  ` -> code ' `` '")
  func spec341() {
    let input = "`  ``  `\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == " `` ")
    #expect(sig(result.root) == "document[paragraph[code(\" `` \")]]")
  }

  // Spec 342: leading space is preserved if directly inside span
  @Test("Spec 342: ` a` -> code ' a'")
  func spec342() {
    let input = "` a`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == " a")
    #expect(sig(result.root) == "document[paragraph[code(\" a\")]]")
  }

  // Spec 343: non-breaking spaces are preserved
  @Test("Spec 343: non-breaking spaces preserved")
  func spec343() {
    let input = "`\u{00A0}b\u{00A0}`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "\u{00A0}b\u{00A0}")
    #expect(sig(result.root) == "document[paragraph[code(\"\u{00A0}b\u{00A0}\")]]")
  }

  // Spec 344: two separate code spans on two lines
  @Test("Spec 344: separate code spans on separate lines")
  func spec344() {
    let input = "`\u{00A0}`\n`  `\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // The HTML shows two <code> in one <p>, so we expect a single paragraph containing two InlineCodeNode
    let codes = para.children.compactMap { $0 as? InlineCodeNode }
    #expect(codes.count == 2)
    #expect(codes[0].code == "\u{00A0}")
    #expect(codes[1].code == "  ")
    #expect(sig(result.root) == "document[paragraph[code(\"\u{00A0}\"),code(\"  \")]]")
  }

  // Spec 345: line breaks collapsed to spaces within code span fenced by ``
  @Test("Spec 345: multiline in code span -> spaces collapsed")
  func spec345() {
    let input = "``\nfoo\nbar  \nbaz\n``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo bar   baz")
    #expect(sig(result.root) == "document[paragraph[code(\"foo bar   baz\")]]")
  }

  // Spec 346: trailing space inside code span preserved
  @Test("Spec 346: trailing space preserved inside code span")
  func spec346() {
    let input = "``\nfoo \n``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo ")
    #expect(sig(result.root) == "document[paragraph[code(\"foo \")]]")
  }

  // Spec 347: soft line break inside code span becomes a space (and trailing space normalized)
  @Test("Spec 347: soft break to space inside span")
  func spec347() {
    let input = "`foo   bar \nbaz`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo   bar  baz")
  }

  // Spec 348: backslash before closing backtick becomes literal backslash in code, remainder parsed as text
  @Test("Spec 348: backslash before closing backtick")
  func spec348() {
    let input = "`foo\\`bar`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? InlineCodeNode)?.code == "foo\\")
    #expect((para.children[1] as? TextNode)?.content == "bar")
    #expect((para.children[2] as? TextNode)?.content == "`")
  }

  // Spec 349: nested single backtick inside double-backtick span
  @Test("Spec 349: double-backtick span containing single backtick")
  func spec349() {
    let input = "``foo`bar``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo`bar")
  }

  // Spec 350: spaces around double backticks inside single-backtick span preserved
  @Test("Spec 350: spaces around `` inside code span")
  func spec350() {
    let input = "` foo `` bar `\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = para.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo `` bar")
  }

  // Spec 351: emphasis markers are literal inside code span
  @Test("Spec 351: emphasis literal inside code span")
  func spec351() {
    let input = "*foo`*`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "*foo")
    #expect((para.children[1] as? InlineCodeNode)?.code == "*")
  }

  // Spec 352: link syntax is literal inside code span
  @Test("Spec 352: link syntax literal inside code span")
  func spec352() {
    let input = "[not a `link](/foo`)\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "[not a ")
    #expect((para.children[1] as? InlineCodeNode)?.code == "link](/foo")
    #expect((para.children[2] as? TextNode)?.content == ")")
  }

  // Spec 353: HTML is escaped inside code span
  @Test("Spec 353: HTML escapes inside code span")
  func spec353() {
    let input = "`<a href=\"`\">`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? InlineCodeNode)?.code == "<a href=\"")
    #expect((para.children[1] as? TextNode)?.content == "\"")
    #expect((para.children[2] as? TextNode)?.content == ">")
  }

  // Spec 354: literal backticks in HTML attribute context (no code span)
  @Test("Spec 354: autolink followed by literal backtick")
  func spec354() {
    let input = "<a href=\"`\">`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Expect a LinkNode followed by a TextNode("`")
    #expect(para.children.count >= 2)
    let links = para.children.compactMap { $0 as? LinkNode }
    #expect(links.count >= 1)
    #expect((para.children.last as? TextNode)?.content == "`")
  }

  // Spec 355: code span around start of autolink literal
  @Test("Spec 355: code then leftover parsed as text with closing '>' and backtick")
  func spec355() {
    let input = "`<https://foo.bar.`baz>`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count >= 3)
    #expect((para.children[0] as? InlineCodeNode)?.code == "<https://foo.bar.")
    // Then text "baz>" and trailing backtick as text
    #expect((para.children[1] as? TextNode)?.content == "baz>")
    #expect((para.children[2] as? TextNode)?.content == "`")
  }

  // Spec 356: autolink consumes url, trailing backtick is literal
  @Test("Spec 356: autolink then literal backtick")
  func spec356() {
    let input = "<https://foo.bar.`baz>`\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Expect a LinkNode followed by a TextNode("`")
    let links = para.children.compactMap { $0 as? LinkNode }
    #expect(links.count == 1)
    if let link = links.first { #expect(link.url == "https://foo.bar.%60baz") }
    #expect((para.children.last as? TextNode)?.content == "`")
  }

  // Spec 357: no code span; text with backticks remains as text
  @Test("Spec 357: not a code span, literal text '```foo``'")
  func spec357() {
    let input = "```foo``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "```foo``")
  }

  // Spec 358: unmatched opening backtick stays literal
  @Test("Spec 358: unmatched backtick literal")
  func spec358() {
    let input = "`foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect((para.children.first as? TextNode)?.content == "`foo")
  }

  // Spec 359: backtick before code span
  @Test("Spec 359: text '`foo' then code 'bar'")
  func spec359() {
    let input = "`foo``bar``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 2)
    #expect((para.children[0] as? TextNode)?.content == "`foo")
    #expect((para.children[1] as? InlineCodeNode)?.code == "bar")
  }
}

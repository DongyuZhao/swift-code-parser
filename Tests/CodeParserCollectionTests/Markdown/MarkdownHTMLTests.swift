import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - HTML Blocks and Inline HTML (Strict)")
struct MarkdownHTMLTests {
  private let h = MarkdownTestHarness()

  // Helper to collect HTML blocks' content
  private func htmlBlocks(in root: CodeNode<MarkdownNodeElement>) -> [HTMLBlockNode] {
    findNodes(in: root, ofType: HTMLBlockNode.self)
  }

  // Using shared childrenTypes/sig from Tests/.../Utils/TestUtils.swift

  private func paraText(_ node: CodeNode<MarkdownNodeElement>) -> [String] {
    findNodes(in: node, ofType: ParagraphNode.self).map { para in
      findNodes(in: para, ofType: TextNode.self).map { $0.content }.joined()
    }
  }

  // Helper: immediate inline children of a paragraph, ignoring line breaks
  private func inlineChildrenIgnoringBreaks(_ p: ParagraphNode) -> [CodeNode<MarkdownNodeElement>] {
    p.children.filter { $0.element != .lineBreak }
  }

  // 118
  @Test("Spec 118: HTML table/pre block is preserved as raw HTML block")
  func spec118() {
    let input = "<table><tr><td>\n<pre>\n**Hello**,\n\n_world_.\n</pre>\n</td></tr></table>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let b = result.root.children.first as? HTMLBlockNode else {
      Issue.record("Expected HTMLBlockNode")
      return
    }
    #expect(b.content == input.trimmingCharacters(in: .newlines))
    #expect(sig(result.root) == "document[html_block]")
  }

  // 119
  @Test("Spec 119: HTML block followed by a paragraph")
  func spec119() {
    let input = "<table>\n  <tr>\n    <td>\n           hi\n    </td>\n  </tr>\n</table>\n\nokay.\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect two top-level nodes: HTMLBlockNode then ParagraphNode("okay.")
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let text = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "okay.")
    // Micro: only a single TextNode
    let inlines149 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines149.count == 1)
    #expect(inlines149.first is TextNode)
    if let hb = result.root.children.first as? HTMLBlockNode {
      let expected = "<table>\n  <tr>\n    <td>\n           hi\n    </td>\n  </tr>\n</table>"
      #expect(hb.content == expected)
    }
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay.\")]]")
  }

  // 120
  @Test("Spec 120: Leading space before <div> still forms HTML block")
  func spec120() {
    let input = " <div>\n  *hello*\n         <foo><a>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = htmlBlocks(in: result.root)
    #expect(blocks.count == 1)
    if let b = blocks.first { #expect(b.content == input.trimmingCharacters(in: .newlines)) }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 121
  @Test("Spec 121: Closing tag line with following text remains in HTML block")
  func spec121() {
    let input = "</div>\n*hi*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let blocks = htmlBlocks(in: result.root)
    #expect(blocks.count == 1)
    if let b = blocks.first { #expect(b.content == input.trimmingCharacters(in: .newlines)) }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 122
  @Test("Spec 122: Uppercase DIV HTML block preserved; markdown inside not parsed")
  func spec122() {
    let input = "<DIV CLASS=\"foo\">\n\n*Markdown*\n\n</DIV>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect: opening HTML block, then a paragraph with emphasis, then closing HTML block
    #expect(result.root.children.count == 3)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(!findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    #expect(result.root.children.last is HTMLBlockNode)
    if let open = result.root.children.first as? HTMLBlockNode {
      #expect(open.content == "<DIV CLASS=\"foo\">")
    }
    if let close = result.root.children.last as? HTMLBlockNode {
      #expect(close.content == "</DIV>")
    }
    #expect(
      sig(result.root) == "document[html_block,paragraph[emphasis[text(\"Markdown\")]],html_block]")
  }

  // 123
  @Test("Spec 123: Multiline attributes HTML block preserved")
  func spec123() {
    let input = "<div id=\"foo\"\n  class=\"bar\">\n</div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(htmlBlocks(in: result.root).count == 1)
    if let b = htmlBlocks(in: result.root).first {
      #expect(b.content == "<div id=\"foo\"\n  class=\"bar\">\n</div>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 124
  @Test("Spec 124: Attribute value spanning lines preserved")
  func spec124() {
    let input = "<div id=\"foo\" class=\"bar\n  baz\">\n</div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(htmlBlocks(in: result.root).count == 1)
    if let b = htmlBlocks(in: result.root).first {
      #expect(b.content == "<div id=\"foo\" class=\"bar\n  baz\">\n</div>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 125
  @Test("Spec 125: HTML block with markdown-looking lines stays raw")
  func spec125() {
    let input = "<div>\n*foo*\n\n*bar*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect HTML block for first two lines, then a paragraph with emphasized 'bar'
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Strict: emphasis should be parsed in paragraph
    #expect(!findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    let text = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(text == "bar")
    if let hb = result.root.children.first as? HTMLBlockNode {
      #expect(hb.content == "<div>\n*foo*")
    }
    #expect(sig(result.root) == "document[html_block,paragraph[emphasis[text(\"bar\")]]]")
  }

  // 126
  @Test("Spec 126: Unfinished tag line stays raw HTML block")
  func spec126() {
    let input = "<div id=\"foo\"\n*hi*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input remains a single HTML block
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 127
  @Test("Spec 127: Broken attribute line kept as raw")
  func spec127() {
    let input = "<div class\nfoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input remains a single HTML block
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 128
  @Test("Spec 128: Strange characters in tag remain raw")
  func spec128() {
    let input = "<div *???-&&&-<---\n*foo*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input remains a single HTML block
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 129
  @Test("Spec 129: Inline HTML block in one line stays raw")
  func spec129() {
    let input = "<div><a href=\"bar\">*foo*</a></div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(htmlBlocks(in: result.root).count == 1)
    if let b = htmlBlocks(in: result.root).first {
      #expect(b.content == "<div><a href=\"bar\">*foo*</a></div>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 130
  @Test("Spec 130: HTML table block preserved")
  func spec130() {
    let input = "<table><tr><td>\nfoo\n</td></tr></table>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(htmlBlocks(in: result.root).count == 1)
    if let b = htmlBlocks(in: result.root).first {
      #expect(b.content == "<table><tr><td>\nfoo\n</td></tr></table>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 131
  @Test("Spec 131: HTML then fenced code remains literal HTML + literal fences")
  func spec131() {
    let input = "<div></div>\n``` c\nint x = 33;\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input is a single HTML block (type 6 continues until blank line)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    #expect(findNodes(in: result.root, ofType: CodeBlockNode.self).isEmpty)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<div></div>\n``` c\nint x = 33;\n```")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 132
  @Test("Spec 132: HTML <a> block preserved with inner markdown-looking text")
  func spec132() {
    let input = "<a href=\"foo\">\n*bar*\n</a>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input is treated as an HTML block
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<a href=\"foo\">\n*bar*\n</a>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 133
  @Test("Spec 133: Custom tag Warning preserved as raw HTML block")
  func spec133() {
    let input = "<Warning>\n*bar*\n</Warning>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<Warning>\n*bar*\n</Warning>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 134
  @Test("Spec 134: Inline tag with attributes preserved")
  func spec134() {
    let input = "<i class=\"foo\">\n*bar*\n</i>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<i class=\"foo\">\n*bar*\n</i>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 135
  @Test("Spec 135: Closing inline tag line preserved with following text")
  func spec135() {
    let input = "</ins>\n*bar*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input remains an HTML block (no blank line)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "</ins>\n*bar*")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 136
  @Test("Spec 136: <del> block preserves inner markdown-looking lines")
  func spec136() {
    let input = "<del>\n*foo*\n</del>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input remains an HTML block (no blank line)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<del>\n*foo*\n</del>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 137
  @Test("Spec 137: <del> with blank lines still raw")
  func spec137() {
    let input = "<del>\n\n*foo*\n\n</del>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect opening HTML block, then paragraph with emphasis, then closing HTML block
    #expect(result.root.children.count == 3)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(!findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    let pText = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(pText == "foo")
    #expect(result.root.children.last is HTMLBlockNode)
    if let open = result.root.children.first as? HTMLBlockNode { #expect(open.content == "<del>") }
    if let close = result.root.children.last as? HTMLBlockNode {
      #expect(close.content == "</del>")
    }
    #expect(
      sig(result.root) == "document[html_block,paragraph[emphasis[text(\"foo\")]],html_block]")
  }

  // 138
  @Test("Spec 138: Inline <del> around markdown becomes inline HTML node or raw")
  func spec138() {
    let input = "<del>*foo*</del>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Paragraph with inline HTML and emphasis inside
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(!findNodes(in: p, ofType: HTMLNode.self).isEmpty)
    #expect(!findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    // Micro: ensure order HTML(open) -> Emphasis("foo") -> HTML(close)
    let inlines168 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines168.count == 3)
    guard let h1 = inlines168.first as? HTMLNode,
      let em = inlines168.dropFirst().first as? EmphasisNode, let h2 = inlines168.last as? HTMLNode
    else {
      Issue.record("Unexpected inline node sequence")
      return
    }
    #expect(h1.content == "<del>")
    let emText168 = findNodes(in: em, ofType: TextNode.self).map { $0.content }.joined()
    #expect(emText168 == "foo")
    // Emphasis must contain exactly one TextNode("foo")
    let emInnerTexts168 = findNodes(in: em, ofType: TextNode.self)
    #expect(emInnerTexts168.count == 1)
    #expect(emInnerTexts168.first?.content == "foo")
    #expect(h2.content == "</del>")
    #expect(sig(result.root) == "document[paragraph[html,emphasis[text(\"foo\")],html]]")
  }

  // 139
  @Test("Spec 139: <pre><code>... okay paragraph after")
  func spec139() {
    let input =
      "<pre language=\"haskell\"><code>\nimport Text.HTML.TagSoup\n\nmain :: IO ()\nmain = print $ parseTags tags\n</code></pre>\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(
        b.content
          == "<pre language=\"haskell\"><code>\nimport Text.HTML.TagSoup\n\nmain :: IO ()\nmain = print $ parseTags tags\n</code></pre>"
      )
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "okay")
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // 140
  @Test("Spec 140: <script> block preserved, followed by paragraph")
  func spec140() {
    let input =
      "<script type=\"text/javascript\">\n// JavaScript example\n\ndocument.getElementById(\"demo\").innerHTML = \"Hello JavaScript!\";\n</script>\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(
        b.content
          == "<script type=\"text/javascript\">\n// JavaScript example\n\ndocument.getElementById(\"demo\").innerHTML = \"Hello JavaScript!\";\n</script>"
      )
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "okay")
    // Micro: only one TextNode
    let inlines170 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines170.count == 1 && inlines170.first is TextNode)
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // H1
  @Test("Spec H1: <textarea> raw HTML block preserved")
  func specH1() {
    let input = "<textarea>\n\n*foo*\n\n_bar_\n\n</textarea>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 141
  @Test("Spec 141: <style> block preserved, followed by paragraph")
  func spec141() {
    let input = "<style\n  type=\"text/css\">\nh1 {color:red;}\n\np {color:blue;}\n</style>\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(
        b.content == "<style\n  type=\"text/css\">\nh1 {color:red;}\n\np {color:blue;}\n</style>")
    } else {
      Issue.record("Expected HTMLBlockNode")
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "okay")
    // Micro: only one TextNode
    let inlines172 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines172.count == 1 && inlines172.first is TextNode)
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // 142
  @Test("Spec 142: <style> unterminated remains raw")
  func spec142() {
    let input = "<style\n  type=\"text/css\">\n\nfoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 143
  @Test("Spec 143: blockquote containing HTML block, then paragraph")
  func spec143() {
    let input = "> <div>\n> foo\n\nbar\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    // Inside blockquote we should have an HTML block
    #expect(!findNodes(in: bq, ofType: HTMLBlockNode.self).isEmpty)
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "bar")
    // Micro: only one TextNode
    let inlines174 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines174.count == 1 && inlines174.first is TextNode)
    #expect(
      sig(result.root)
        == "document[blockquote[html_block,paragraph[text(\"foo\")]],paragraph[text(\"bar\")]]")
  }

  // 144
  @Test("Spec 144: list item with HTML block as first child, then another li")
  func spec144() {
    let input = "- <div>\n- foo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let ul = result.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UL")
      return
    }
    #expect(ul.children.count == 2)
    if let firstLi = ul.children.first as? ListItemNode {
      #expect(!findNodes(in: firstLi, ofType: HTMLBlockNode.self).isEmpty)
      if let hb = findNodes(in: firstLi, ofType: HTMLBlockNode.self).first {
        #expect(hb.content == "<div>")
      }
    }
    if let secondLi = ul.children.last as? ListItemNode {
      let p = findNodes(in: secondLi, ofType: ParagraphNode.self)
      #expect(p.count == 1)
      let t = findNodes(in: secondLi, ofType: TextNode.self).map { $0.content }.joined()
      #expect(t == "foo")
    }
    #expect(
      sig(result.root)
  == "document[unordered_list(level:1)[list_item[html_block],list_item[paragraph[text(\"foo\")]]]]")
  }

  // 145
  @Test("Spec 145: <style> block then paragraph with emphasis")
  func spec145() {
    let input = "<style>p{color:red;}</style>\n*foo*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect two blocks: HTML block then paragraph (emphasis may be parsed)
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Micro: paragraph consists solely of single Emphasis("foo")
    let inlines176 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines176.count == 1)
    guard let em176 = inlines176.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    let t = findNodes(in: em176, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "foo")
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<style>p{color:red;}</style>")
    }
    #expect(sig(result.root) == "document[html_block,paragraph[emphasis[text(\"foo\")]]]")
  }

  // 146
  @Test("Spec 146: HTML comment then paragraph with emphasis")
  func spec146() {
    let input = "<!-- foo -->*bar*\n*baz*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // First block: HTML comment; next: paragraph with only 'baz' emphasized
    #expect(result.root.children.count == 2)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<!-- foo -->*bar*")
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    // Micro: paragraph consists solely of single Emphasis("baz")
    let inlines177 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines177.count == 1)
    guard let em177 = inlines177.first as? EmphasisNode else {
      Issue.record("Expected EmphasisNode")
      return
    }
    let t = findNodes(in: em177, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "baz")
    #expect(sig(result.root) == "document[html_block,paragraph[emphasis[text(\"baz\")]]]")
  }

  // 147
  @Test("Spec 147: <script> then '1. *bar*' remains raw")
  func spec147() {
    let input = "<script>\nfoo\n</script>1. *bar*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire line after </script> is part of same HTML block; no list/paragraph created
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 148
  @Test("Spec 148: HTML comment block then paragraph 'okay'")
  func spec148() {
    let input = "<!-- Foo\n\nbar\n   baz -->\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<!-- Foo\n\nbar\n   baz -->")
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "okay")
    // Micro: only one TextNode
    let inlines179 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines179.count == 1 && inlines179.first is TextNode)
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // 149
  @Test("Spec 149: PHP block preserved then paragraph 'okay'")
  func spec149() {
    let input = "<?php\n\n  echo '>';\n\n?>\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<?php\n\n  echo '>';\n\n?>")
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "okay")
    // Micro: only one TextNode
    let inlines180 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines180.count == 1 && inlines180.first is TextNode)
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // 150
  @Test("Spec 150: DOCTYPE line preserved as HTML block")
  func spec150() {
    let input = "<!DOCTYPE html>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<!DOCTYPE html>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 151
  @Test("Spec 151: CDATA block preserved then paragraph 'okay'")
  func spec151() {
    let input =
      "<![CDATA[\nfunction matchwo(a,b)\n{\n  if (a < b && a < 0) then {\n    return 1;\n\n  } else {\n\n    return 0;\n  }\n}\n]]>\nokay\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(
        b.content
          == "<![CDATA[\nfunction matchwo(a,b)\n{\n  if (a < b && a < 0) then {\n    return 1;\n\n  } else {\n\n    return 0;\n  }\n}\n]]>"
      )
    }
    guard let p = result.root.children.last as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "okay")
    // Micro: only one TextNode
    let inlines182 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines182.count == 1 && inlines182.first is TextNode)
    #expect(sig(result.root) == "document[html_block,paragraph[text(\"okay\")]]")
  }

  // 152
  @Test("Spec 152: Indented HTML comment becomes raw; next is indented code block")
  func spec152() {
    let input = "  <!-- foo -->\n\n    <!-- foo -->\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // First (2-space) is HTML block; second (4-space) is indented code block
    if let hb = htmlBlocks(in: result.root).first {
      #expect(hb.content == "  <!-- foo -->")
    } else {
      Issue.record("Expected HTML block present")
    }
    let codes = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codes.contains { $0.source == "<!-- foo -->" })
    #expect(childrenTypes(result.root) == [.htmlBlock, .codeBlock])
    #expect(sig(result.root) == "document[html_block,code_block(\"<!-- foo -->\")]")
  }

  // 153
  @Test("Spec 153: Indented HTML tag then code block of '<div>'")
  func spec153() {
    let input = "  <div>\n\n    <div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    if let hb = htmlBlocks(in: result.root).first {
      #expect(hb.content == "  <div>")
    } else {
      Issue.record("Expected HTML block present")
    }
    let codes = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(codes.contains { $0.source == "<div>" })
    #expect(childrenTypes(result.root) == [.htmlBlock, .codeBlock])
    #expect(sig(result.root) == "document[html_block,code_block(\"<div>\")]")
  }

  // 154
  @Test("Spec 154: Paragraph 'Foo' then HTML block <div>bar</div>")
  func spec154() {
    let input = "Foo\n<div>\nbar\n</div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ParagraphNode)
    if let hb = htmlBlocks(in: result.root).first {
      #expect(hb.content == "<div>\nbar\n</div>")
    } else {
      Issue.record("Expected HTML block present")
    }
    #expect(sig(result.root) == "document[paragraph[text(\"Foo\")],html_block]")
  }

  // 155
  @Test("Spec 155: HTML block then raw '*foo*' remains in HTML block")
  func spec155() {
    let input = "<div>\nbar\n</div>\n*foo*\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Entire input should be a single HTML block (type 6 continues until blank line)
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let hb = result.root.children.first as? HTMLBlockNode {
      #expect(hb.content == "<div>\nbar\n</div>\n*foo*")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 156
  @Test("Spec 156: Paragraph with inline <a> spans lines and stays paragraph")
  func spec156() {
    let input = "Foo\n<a href=\"bar\">\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(!findNodes(in: p, ofType: HTMLNode.self).isEmpty)
    // No emphasis present
    #expect(findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    // Micro: exact sequence Text("Foo"), HTML("<a href=\"bar\">") , Text("baz") ignoring breaks
    let inlines187 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines187.count == 3)
    guard let t1 = inlines187[0] as? TextNode,
      let h = inlines187[1] as? HTMLNode,
      let t2 = inlines187[2] as? TextNode
    else {
      Issue.record("Inline sequence not [Text, HTML, Text]")
      return
    }
    #expect(t1.content == "Foo")
    #expect(h.content == "<a href=\"bar\">")
    #expect(t2.content == "baz")
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"Foo\"),line_break(soft),html,line_break(soft),text(\"baz\")]]"
    )
  }

  // 157
  @Test("Spec 157: <div> with inner markdown paragraph produces HTML block")
  func spec157() {
    let input = "<div>\n\n*Emphasized* text.\n\n</div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect the wrapper tags as HTML blocks and inner paragraph parsed
    #expect(result.root.children.count == 3)
    #expect(result.root.children.first is HTMLBlockNode)
    guard let p = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected inner ParagraphNode")
      return
    }
    #expect(!findNodes(in: p, ofType: EmphasisNode.self).isEmpty)
    #expect(result.root.children.last is HTMLBlockNode)
    let t = findNodes(in: p, ofType: TextNode.self).map { $0.content }.joined()
    #expect(t == "Emphasized text.")
    if let open = result.root.children.first as? HTMLBlockNode { #expect(open.content == "<div>") }
    if let close = result.root.children.last as? HTMLBlockNode {
      #expect(close.content == "</div>")
    }
    // Micro: inline order Emphasis("Emphasized") then Text(" text.")
    let inlines188 = inlineChildrenIgnoringBreaks(p)
    #expect(inlines188.count == 2)
    guard let em188 = inlines188.first as? EmphasisNode, let txt188 = inlines188.last as? TextNode
    else {
      Issue.record("Unexpected inline order in spec188")
      return
    }
    let emTxt188 = findNodes(in: em188, ofType: TextNode.self).map { $0.content }.joined()
    #expect(emTxt188 == "Emphasized")
    #expect(txt188.content == " text.")
    #expect(
      sig(result.root)
        == "document[html_block,paragraph[emphasis[text(\"Emphasized\")],text(\" text.\")],html_block]"
    )
  }

  // 158
  @Test("Spec 158: <div> with inline markdown-looking text stays raw")
  func spec158() {
    let input = "<div>\n*Emphasized* text.\n</div>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // No blank line: entire thing is a single HTML block; no paragraph created
    #expect(result.root.children.count == 1)
    #expect(result.root.children.first is HTMLBlockNode)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == "<div>\n*Emphasized* text.\n</div>")
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 159
  @Test("Spec 159: HTML table with blank lines preserved")
  func spec159() {
    let input = "<table>\n\n<tr>\n\n<td>\nHi\n</td>\n\n</tr>\n\n</table>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    if let b = result.root.children.first as? HTMLBlockNode {
      #expect(b.content == input.trimmingCharacters(in: .newlines))
    }
    #expect(sig(result.root) == "document[html_block]")
  }

  // 160
  @Test("Spec 160: HTML table with inner <td> turned into code block when indented")
  func spec160() {
    let input = "<table>\n\n  <tr>\n\n    <td>\n      Hi\n    </td>\n\n  </tr>\n\n</table>\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    // Expect presence of an indented code block containing the inner td region
    let codes = findNodes(in: result.root, ofType: CodeBlockNode.self)
    #expect(!codes.isEmpty)
    #expect(codes.count == 1)
    #expect(codes.first?.source == "<table>\n  <tr>\n    <td>Hi\n  </tr>\n</table>")
    let htmls = htmlBlocks(in: result.root)
    #expect(htmls.contains { $0.content == "<table>" })
    #expect(htmls.contains { $0.content == "</table>" })
    #expect(childrenTypes(result.root) == [.htmlBlock, .codeBlock, .htmlBlock])
  }

  // H2
  @Test("Spec H2: Multiple spaces preserved")
  func specH2() {
    let input = "Multiple     spaces\n"
    let r = h.parser.parse(input, language: h.language)
    #expect(r.errors.isEmpty)
    guard let p = r.root.children.first as? ParagraphNode, let t = p.children.first as? TextNode
    else {
      Issue.record("Expected ParagraphNode with TextNode")
      return
    }
    #expect(childrenTypes(p) == [.text])
    #expect(t.content == "Multiple     spaces")
    #expect(sig(r.root) == "document[paragraph[text(\"Multiple     spaces\")]]")
  }
}

import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Fenced Code Blocks (Strict)")
struct MarkdownFencedCodeBlocksTests {
  private let h = MarkdownTestHarness()

  private func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
    findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
  }

  // 89: backtick fence with angle brackets content
  @Test("Spec 89: ``` fence with content '<' and ' >'")
  func spec89() {
    let input = "```\n<\n >\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "<\n >")
    #expect(sig(result.root) == "document[code_block(\"<\\n >\")]")
  }

  // 90: tilde fence variant
  @Test("Spec 90: ~~~ fence with content '<' and ' >'")
  func spec90() {
    let input = "~~~\n<\n >\n~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "<\n >")
    #expect(sig(result.root) == "document[code_block(\"<\\n >\")]")
  }

  // 91: two backticks => inline code, not fenced block
  @Test("Spec 91: `` fence is inline code, not block")
  func spec91() {
    let input = "``\nfoo\n``\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let code = p.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(code.code == "foo")
    #expect(sig(result.root) == "document[paragraph[code(\"foo\")]]")
  }

  // 92: closing fence must match the marker type
  @Test("Spec 92: ``` with inner ~~~ kept as content")
  func spec92() {
    let input = "```\naaa\n~~~\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n~~~")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n~~~\")]")
  }

  // 93: ~~~ fence with inner ``` kept as content
  @Test("Spec 93: ~~~ with inner ``` kept as content")
  func spec93() {
    let input = "~~~\naaa\n```\n~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n```")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n```\")]")
  }

  // 94: closing fence can be longer than opening
  @Test("Spec 94: closing fence longer is allowed")
  func spec94() {
    let input = "````\naaa\n```\n``````\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n```")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n```\")]")
  }

  // 95: tildes variant
  @Test("Spec 95: tildes with shorter inner kept")
  func spec95() {
    let input = "~~~~\naaa\n~~~\n~~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n~~~")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n~~~\")]")
  }

  // 96: unterminated fence => empty code block
  @Test("Spec 96: unterminated fence yields empty code block")
  func spec96() {
    let input = "```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "")
    #expect(sig(result.root) == "document[code_block(\"\")]")
  }

  // 97: content continues to EOF
  @Test("Spec 97: content continues to EOF")
  func spec97() {
    let input = "`````\n\n```\naaa\n"  // 5 backticks open, no closing
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "\n```\naaa\n")
    #expect(sig(result.root) == "document[code_block(\"\\n```\\naaa\\n\")]")
  }

  // 98: fenced code inside blockquote
  @Test("Spec 98: fenced code inside blockquote, then paragraph")
  func spec98() {
    let input = "> ```\n> aaa\n\nbbb\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let bq = result.root.children[0] as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let code = findNodes(in: bq, ofType: CodeBlockNode.self).first else {
      Issue.record("Expected CodeBlockNode in blockquote")
      return
    }
    #expect(code.source == "aaa")
    guard let p = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(innerText(p) == "bbb")
    #expect(
      sig(result.root) == "document[blockquote[code_block(\"aaa\")],paragraph[text(\"bbb\")]]")
  }

  // 99: blank line and spaces preserved inside code block
  @Test("Spec 99: blank line and spaces preserved")
  func spec99() {
    let input = "```\n\n  \n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "\n  ")
    #expect(sig(result.root) == "document[code_block(\"\\n  \")]")
  }

  // 100: empty code block
  @Test("Spec 100: empty code block")
  func spec100() {
    let input = "```\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source.isEmpty)
    #expect(sig(result.root) == "document[code_block(\"\")]")
  }

  // 101: opening fence may be indented ≤ 3 spaces
  @Test("Spec 101: opening fence indented by 1 space")
  func spec101() {
    let input = " ```\n aaa\naaa\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\naaa")
    #expect(sig(result.root) == "document[code_block(\"aaa\\naaa\")]")
  }

  // 102: fence can be indented up to 3 spaces, content dedented
  @Test("Spec 102: opening/closing fences indented 2 spaces")
  func spec102() {
    let input = "  ```\naaa\n  aaa\naaa\n  ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\naaa\naaa")
    #expect(sig(result.root) == "document[code_block(\"aaa\\naaa\\naaa\")]")
  }

  // 103: internal indentation kept after baseline removal
  @Test("Spec 103: internal indentation retained")
  func spec103() {
    let input = "   ```\n   aaa\n    aaa\n  aaa\n   ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n aaa\naaa")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n aaa\\naaa\")]")
  }

  // 104: 4-space indented fences are indented code blocks, not fenced
  @Test("Spec 104: 4-space indented fence becomes indented code block")
  func spec104() {
    let input = "    ```\n    aaa\n    ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "```\naaa\n```")
    #expect(sig(result.root) == "document[code_block(\"```\\naaa\\n```\")]")
  }

  // 105: closing fence can be indented ≤ 3 spaces
  @Test("Spec 105: closing fence indented two spaces")
  func spec105() {
    let input = "```\naaa\n  ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa")
    #expect(sig(result.root) == "document[code_block(\"aaa\")]")
  }

  // 106: fences indented up to 3 spaces still work
  @Test("Spec 106: opening fence indented 3, closing 2")
  func spec106() {
    let input = "   ```\naaa\n  ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa")
    #expect(sig(result.root) == "document[code_block(\"aaa\")]")
  }

  // 107: closing fence indented 4 => treated as content
  @Test("Spec 107: closing fence indented 4 becomes content line")
  func spec107() {
    let input = "```\naaa\n    ```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n    ```")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n    ```\")]")
  }

  // 108: three backticks separated by spaces form inline code
  @Test("Spec 108: '``` ```' inline code, not fenced block")
  func spec108() {
    let input = "``` ```\naaa\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let ic = p.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(ic.code == " ")
    // ensure following text "aaa" exists
    #expect(p.children.contains { ($0 as? TextNode)?.content == "aaa" })
    #expect(sig(result.root) == "document[paragraph[code(\" \"),text(\"aaa\")]]")
  }

  // 109: tildes with unmatched inner kept as content
  @Test("Spec 109: tildes fence with inner '~~~ ~~' kept")
  func spec109() {
    let input = "~~~~~~\naaa\n~~~ ~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "aaa\n~~~ ~~")
    #expect(sig(result.root) == "document[code_block(\"aaa\\n~~~ ~~\")]")
  }

  // 110: paragraph, code block, paragraph
  @Test("Spec 110: p, fenced code, p")
  func spec110() {
    let input = "foo\n```\nbar\n```\nbaz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    #expect(result.root.children[0] is ParagraphNode)
    if let code = result.root.children[1] as? CodeBlockNode {
      #expect(code.source == "bar")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    #expect(result.root.children[2] is ParagraphNode)
    #expect(
      sig(result.root)
        == "document[paragraph[text(\"foo\")],code_block(\"bar\"),paragraph[text(\"baz\")]]")
  }

  // 111: setext h2, code block, atx h1
  @Test("Spec 111: h2, fenced code, h1")
  func spec111() {
    let input = "foo\n---\n~~~\nbar\n~~~\n# baz\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 3)
    if let h2 = result.root.children[0] as? HeaderNode {
      #expect(h2.level == 2)
    } else {
      Issue.record("Expected HeaderNode level 2")
    }
    if let code = result.root.children[1] as? CodeBlockNode {
      #expect(code.source == "bar")
    } else {
      Issue.record("Expected CodeBlockNode")
    }
    if let h1 = result.root.children[2] as? HeaderNode {
      #expect(h1.level == 1)
    } else {
      Issue.record("Expected HeaderNode level 1")
    }
    #expect(
      sig(result.root)
        == "document[heading(level:2)[text(\"foo\")],code_block(\"bar\"),heading(level:1)[text(\"baz\")]]"
    )
  }

  // 112: info string language ruby
  @Test("Spec 112: language from info string: ruby")
  func spec112() {
    let input = "```ruby\ndef foo(x)\n  return 3\nend\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == "ruby")
    #expect(code.source == "def foo(x)\n  return 3\nend")
    #expect(sig(result.root) == "document[code_block(\"def foo(x)\\n  return 3\\nend\")]")
  }

  // 113: info string with extra garbage; language is first word
  @Test("Spec 113: language is first word of info string")
  func spec113() {
    let input = "~~~~    ruby startline=3 $%@#$\ndef foo(x)\n  return 3\nend\n~~~~~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == "ruby")
    #expect(code.source == "def foo(x)\n  return 3\nend")
    #expect(sig(result.root) == "document[code_block(\"def foo(x)\\n  return 3\\nend\")]")
  }

  // 114: language can be ';'
  @Test("Spec 114: language can be non-alnum like ';'")
  func spec114() {
    let input = "````;\n````\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == ";")
    #expect(code.source.isEmpty)
    #expect(sig(result.root) == "document[code_block(\"\")]")
  }

  // 115: inline code with spaced backticks, not fenced block
  @Test("Spec 115: '``` aa ```' is inline code 'aa'")
  func spec115() {
    let input = "``` aa ```\nfoo\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let p = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    guard let ic = p.children.first as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    #expect(ic.code == "aa")
    // following text "foo" remains in same paragraph
    #expect(p.children.contains { ($0 as? TextNode)?.content == "foo" })
    #expect(sig(result.root) == "document[paragraph[code(\"aa\"),text(\"foo\")]]")
  }

  // 116: info string up to first space considered language
  @Test("Spec 116: language is 'aa' from 'aa ``` ~~~'")
  func spec116() {
    let input = "~~~ aa ``` ~~~\nfoo\n~~~\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == "aa")
    #expect(code.source == "foo")
    #expect(sig(result.root) == "document[code_block(\"foo\")]")
  }

  // 117: backticks in content when not closing
  @Test("Spec 117: content line '``` aaa' kept inside code")
  func spec117() {
    let input = "```\n``` aaa\n```\n"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.source == "``` aaa")
    #expect(sig(result.root) == "document[code_block(\"``` aaa\")]")
  }

}

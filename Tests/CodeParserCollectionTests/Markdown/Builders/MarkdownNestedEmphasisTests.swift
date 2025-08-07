import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Nested Emphasis Tests")
struct MarkdownNestedEmphasisTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Emphasis with link and code")
  func emphasisWithLinkAndCode() {
    let input = "*see [link](url) `code`*"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode,
      let emph = para.children.first as? EmphasisNode
    else {
      Issue.record("Expected EmphasisNode inside Paragraph")
      return
    }
    #expect(emph.children.count == 4)
    #expect(emph.children[0] is TextNode)
    #expect(emph.children[1] is LinkNode)
    #expect(emph.children[2] is TextNode)
    #expect(emph.children[3] is InlineCodeNode)
  }

  @Test("Strong with image and HTML")
  func strongWithImageAndHTML() {
    let input = "**image ![alt](img.png) <b>bold</b>**"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode,
      let strong = para.children.first as? StrongNode
    else {
      Issue.record("Expected StrongNode inside Paragraph")
      return
    }
    #expect(strong.children.count == 4)
    #expect(strong.children[0] is TextNode)
    #expect(strong.children[1] is ImageNode)
    #expect(strong.children[2] is TextNode)
    #expect(strong.children[3] is HTMLNode)
  }
}

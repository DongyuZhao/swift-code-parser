import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown CommonMark Compliance Tests")
struct MarkdownCommonMarkTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Heading parsing")
  func heading() {
    let input = "# Title"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let header = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(header.level == 1)
    #expect(header.first(where: { $0.element == .text }) != nil)
  }

  @Test("Paragraph with emphasis and strong")
  func paragraphEmphasisStrong() {
    let input = "This is *italic* and **bold**."
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.first(where: { $0.element == .emphasis }) != nil)
    #expect(para.first(where: { $0.element == .strong }) != nil)
  }

  @Test("Blockquote parsing")
  func blockquote() {
    let input = "> quote"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is BlockquoteNode)
  }

  @Test("Fenced code block parsing")
  func codeBlock() {
    let input = "```swift\nlet x = 1\n```"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let code = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(code.language == "swift")
  }

  @Test("Ordered and unordered list parsing")
  func lists() {
    let input = """
- one
- two

1. first
2. second
"""
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is OrderedListNode)
  }

  @Test("Link and image parsing")
  func linkAndImage() {
    let input = """
    ![alt](img.png)

    [link](https://example.com)
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    guard let imageParagraph = result.root.children[0] as? ParagraphNode else {
      Issue.record("Expected paragraph containing image")
      return
    }
    #expect(imageParagraph.first(where: { $0.element == .image }) != nil)
    guard let linkParagraph = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected paragraph containing link")
      return
    }
    #expect(linkParagraph.first(where: { $0.element == .link }) != nil)
  }

  @Test("Thematic break parsing")
  func thematicBreak() {
    let input = "---"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.first is ThematicBreakNode)
  }
}


import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Token Builder Tests")
struct MarkdownTokenBuilderTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Heading builder appends header node with text")
  func headingBuilderAppendsHeaderNodeWithText() {
    let input = "# Hello"
    let result = parser.parse(input, language: language)

    // Expect one child: HeaderNode
    #expect(result.root.children.count == 1)
    let header = result.root.children.first as? HeaderNode
    #expect(header != nil, "Expected a HeaderNode as first child")
    #expect(header?.level == 1)  // Level 1 for single '#'

    // HeaderNode should contain a TextNode with content "Hello"
    let headerChildren = header?.children ?? []
    #expect(headerChildren.count == 1)
    if let textNode = headerChildren.first as? TextNode {
      #expect(textNode.content == "Hello")
    } else {
      Issue.record("Expected TextNode inside HeaderNode")
    }

    // No errors
    #expect(result.errors.isEmpty)
  }

  @Test("Text builder appends text node to root")
  func textBuilderAppendsTextNodeToRoot() {
    let input = "Hello World"
    let result = parser.parse(input, language: language)

    // Expect a paragraph with one TextNode
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    if let textNode = para.children.first as? TextNode {
      #expect(textNode.content == "Hello World")
    } else {
      Issue.record("Expected TextNode inside Paragraph")
    }

    #expect(result.errors.isEmpty)
  }

  @Test("Newline builder resets context to parent")
  func newlineBuilderResetsContextToParent() {
    let input = "# Title\nSubtitle"
    let result = parser.parse(input, language: language)

    // After header parse, Title in HeaderNode, then newline resets context, Subtitle appended to root

    // Document should have two children: HeaderNode and ParagraphNode
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is HeaderNode, "First child should be HeaderNode")
    guard let para = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected ParagraphNode after newline")
      return
    }
    if let subtitleNode = para.children.first as? TextNode {
      #expect(subtitleNode.content == "Subtitle")
    } else {
      Issue.record("Expected Subtitle as TextNode")
    }

    #expect(result.errors.isEmpty)
  }
}

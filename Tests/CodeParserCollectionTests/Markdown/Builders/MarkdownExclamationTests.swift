import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("ExclamationTests")
struct ExclamationTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Exclamation in text")
  func exclamationInText() {
    let input = "Hello! Everyone"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    if let text = para.children.first as? TextNode {
      #expect(text.content == "Hello! Everyone")
    } else {
      Issue.record("Expected TextNode")
    }
  }

  @Test("Exclamation in heading")
  func exclamationInHeading() {
    let input = "# This is a heading!"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let heading = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(heading.children.count == 1)
    if let text = heading.children.first as? TextNode {
      #expect(text.content == "This is a heading!")
    } else {
      Issue.record("Expected TextNode inside HeaderNode")
    }
  }
}

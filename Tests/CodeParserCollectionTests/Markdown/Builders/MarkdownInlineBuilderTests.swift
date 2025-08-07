import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Inline Builder Tests")
struct MarkdownInlineBuilderTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Italic text parsing")
  func italicBuilderParsesItalicText() {
    let input = "*italic*"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let emph = para.children.first as? EmphasisNode
    #expect(emph != nil)
    #expect(emph?.children.count == 1)
    if let text = emph?.children.first as? TextNode {
      #expect(text.content == "italic")
    } else {
      Issue.record("Expected TextNode inside EmphasisNode")
    }
  }

  @Test("Bold text parsing")
  func boldBuilderParsesStrongText() {
    let input = "**bold**"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let strong = para.children.first as? StrongNode
    #expect(strong != nil)
    #expect(strong?.children.count == 1)
    if let text = strong?.children.first as? TextNode {
      #expect(text.content == "bold")
    } else {
      Issue.record("Expected TextNode inside StrongNode")
    }
  }

  @Test("Nested emphasis parsing")
  func nestedEmphasisParsesBoldAndItalic() {
    let input = "**bold *and italic***"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    guard let strong = para.children.first as? StrongNode else {
      Issue.record("Expected StrongNode")
      return
    }
    #expect(strong.children.count == 2)
    if let text = strong.children.first as? TextNode {
      #expect(text.content == "bold ")
    } else {
      Issue.record("Expected TextNode inside StrongNode")
    }
    guard let innerEmphasis = strong.children.last as? EmphasisNode else {
      Issue.record("Expected nested EmphasisNode")
      return
    }
    #expect(innerEmphasis.children.count == 1)
    if let innerText = innerEmphasis.children.first as? TextNode {
      #expect(innerText.content == "and italic")
    } else {
      Issue.record("Expected TextNode inside EmphasisNode")
    }
  }

  @Test("Inline code parsing")
  func inlineCodeBuilderParsesInlineCode() {
    let input = "`code`"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let code = para.children.first as? InlineCodeNode
    #expect(code != nil)
    #expect(code?.code == "code")
  }

  @Test("Inline formula parsing")
  func inlineFormulaBuilderParsesFormula() {
    let input = "$x^2$"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let formula = para.children.first as? FormulaNode
    #expect(formula != nil)
    #expect(formula?.expression == "x^2")
  }

  @Test("Autolink parsing")
  func autolinkBuilderParsesAutolink() {
    let urlString = "https://example.com"
    let input = "<\(urlString)>"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let link = para.children.first as? LinkNode
    #expect(link != nil)
    #expect(link?.url == urlString)
    #expect(link?.title == urlString)
  }

  @Test("Bare URL parsing")
  func uRLBuilderParsesBareURL() {
    let urlString = "https://example.com"
    let input = urlString
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    let link = para.children.first as? LinkNode
    #expect(link != nil)
    #expect(link?.url == urlString)
    #expect(link?.title == urlString)
  }

  @Test("HTML inline parsing")
  func hTMLInlineBuilderParsesEntityAndTag() {
    let input = "&amp;<b>bold</b>"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 2)
    // First is HTML entity
    let entity = para.children[0] as? HTMLNode
    #expect(entity != nil)
    #expect(entity?.content == "&amp;")
    // Second is HTML tag
    let tag = para.children[1] as? HTMLNode
    #expect(tag != nil)
    // Name is not used for inline HTML
    #expect(tag?.content == "<b>bold</b>")
  }

  @Test("Blockquote parsing")
  func blockquoteBuilderParsesBlockquote() {
    let input = "> hello"
    let result = parser.parse(input, language: language)

    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    let bq = result.root.children.first as? BlockquoteNode
    #expect(bq != nil)
    #expect(bq?.children.count == 1)
    if let text = bq?.children.first as? TextNode {
      #expect(text.content == "hello")
    } else {
      Issue.record("Expected TextNode inside BlockquoteNode")
    }
  }
}

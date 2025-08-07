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

  @Test("ATX headings")
  func atxHeadings() {
    for level in 1...6 {
      let input = String(repeating: "#", count: level) + " Title"
      let result = parser.parse(input, language: language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 1)
      guard let header = result.root.children.first as? HeaderNode else {
        Issue.record("Expected HeaderNode for level \(level)")
        continue
      }
      #expect(header.level == level)
      guard let textNode = header.children.first as? TextNode else {
        Issue.record("Expected TextNode in header for level \(level)")
        continue
      }
      #expect(textNode.content == "Title")
    }
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
    #expect(para.children.count == 5)
    guard let text1 = para.children[0] as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(text1.content == "This is ")

    guard let emphasis = para.children[1] as? EmphasisNode,
      let emphasisText = emphasis.children.first as? TextNode
    else {
      Issue.record("Expected Emphasis with Text")
      return
    }
    #expect(emphasisText.content == "italic")

    guard let text2 = para.children[2] as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(text2.content == " and ")

    guard let strong = para.children[3] as? StrongNode,
      let strongText = strong.children.first as? TextNode
    else {
      Issue.record("Expected Strong with Text")
      return
    }
    #expect(strongText.content == "bold")

    guard let text3 = para.children[4] as? TextNode else {
      Issue.record("Expected TextNode")
      return
    }
    #expect(text3.content == ".")
  }

  @Test("Blockquote parsing")
  func blockquote() {
    let input = "> quote"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let blockquote = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let para = blockquote.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode inside BlockquoteNode")
      return
    }
    guard let text = para.children.first as? TextNode else {
      Issue.record("Expected TextNode inside ParagraphNode")
      return
    }
    #expect(text.content == "quote")
  }

  @Test("Consecutive blockquote lines should form one blockquote with multiple paragraphs")
  func consecutiveBlockquoteLines() {
    let input = """
      > Quote line one
      > Quote line two
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Should have exactly one blockquote
    let blockquotes = result.root.children.compactMap { $0 as? BlockquoteNode }
    #expect(
      blockquotes.count == 1, "Should have exactly one blockquote, but found \(blockquotes.count)")

    guard let blockquote = blockquotes.first else {
      Issue.record("No blockquote found")
      return
    }

    // The blockquote should contain two paragraphs
    let paragraphs = blockquote.children.compactMap { $0 as? ParagraphNode }
    #expect(
      paragraphs.count == 2, "Blockquote should contain 2 paragraphs, but found \(paragraphs.count)"
    )

    // Verify paragraph contents
    if paragraphs.count >= 2 {
      if let text1 = paragraphs[0].children.first as? TextNode {
        #expect(text1.content == "Quote line one")
      } else {
        Issue.record("First paragraph should contain text 'Quote line one'")
      }

      if let text2 = paragraphs[1].children.first as? TextNode {
        #expect(text2.content == "Quote line two")
      } else {
        Issue.record("Second paragraph should contain text 'Quote line two'")
      }
    }
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
    #expect(code.source == "let x = 1")
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

    guard let ulist = result.root.children[0] as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ulist.children.count == 2)
    guard let item1 = ulist.children[0] as? ListItemNode,
      let para1 = item1.children.first as? ParagraphNode,
      let text1 = para1.children.first as? TextNode
    else {
      Issue.record("Invalid unordered list item 1 structure")
      return
    }
    #expect(text1.content == "one")

    guard let item2 = ulist.children[1] as? ListItemNode,
      let para2 = item2.children.first as? ParagraphNode,
      let text2 = para2.children.first as? TextNode
    else {
      Issue.record("Invalid unordered list item 2 structure")
      return
    }
    #expect(text2.content == "two")

    guard let olist = result.root.children[1] as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(olist.children.count == 2)
    guard let item3 = olist.children[0] as? ListItemNode,
      let para3 = item3.children.first as? ParagraphNode,
      let text3 = para3.children.first as? TextNode
    else {
      Issue.record("Invalid ordered list item 1 structure")
      return
    }
    #expect(text3.content == "first")

    guard let item4 = olist.children[1] as? ListItemNode,
      let para4 = item4.children.first as? ParagraphNode,
      let text4 = para4.children.first as? TextNode
    else {
      Issue.record("Invalid ordered list item 2 structure")
      return
    }
    #expect(text4.content == "second")
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
    guard let image = imageParagraph.children.first as? ImageNode else {
      Issue.record("Expected ImageNode")
      return
    }
    #expect(image.alt == "alt")
    #expect(image.url == "img.png")

    guard let linkParagraph = result.root.children[1] as? ParagraphNode else {
      Issue.record("Expected paragraph containing link")
      return
    }
    guard let link = linkParagraph.children.first as? LinkNode else {
      Issue.record("Expected LinkNode")
      return
    }
    #expect(link.url == "https://example.com")
    guard let linkText = link.children.first as? TextNode else {
      Issue.record("Expected text within link")
      return
    }
    #expect(linkText.content == "link")
  }

  @Test("Thematic break parsing")
  func thematicBreak() {
    let inputs = ["---", "***", "___"]
    for input in inputs {
      let result = parser.parse(input, language: language)
      #expect(result.errors.isEmpty)
      #expect(result.root.children.count == 1)
      #expect(result.root.children.first is ThematicBreakNode, "Failed for input: \(input)")
    }
  }
}

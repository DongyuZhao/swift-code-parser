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
      blockquotes.count == 1, "Should have exactly one blockquote, but found \(blockquotes.count)"
    )

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

  @Test("Nested lists parsing")
  func nestedLists() {
    let input = """
      - Item 1
        - Nested item 1.1
        - Nested item 1.2
      - Item 2
        1. Nested ordered 2.1
        2. Nested ordered 2.2
      - Item 3
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)

    guard let ulist = result.root.children[0] as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ulist.children.count == 3)

    // Check first item with nested unordered list
    guard let item1 = ulist.children[0] as? ListItemNode else {
      Issue.record("Expected first ListItemNode")
      return
    }
    #expect(item1.children.count == 2) // paragraph + nested list

    guard let para1 = item1.children[0] as? ParagraphNode,
          let text1 = para1.children.first as? TextNode else {
      Issue.record("Expected paragraph in first item")
      return
    }
    #expect(text1.content == "Item 1")

    guard let nestedList1 = item1.children[1] as? UnorderedListNode else {
      Issue.record("Expected nested unordered list in first item")
      return
    }
    #expect(nestedList1.children.count == 2)

    // Check second item with nested ordered list
    guard let item2 = ulist.children[1] as? ListItemNode else {
      Issue.record("Expected second ListItemNode")
      return
    }
    #expect(item2.children.count == 2) // paragraph + nested list

    guard let para2 = item2.children[0] as? ParagraphNode,
          let text2 = para2.children.first as? TextNode else {
      Issue.record("Expected paragraph in second item")
      return
    }
    #expect(text2.content == "Item 2")

    guard let nestedList2 = item2.children[1] as? OrderedListNode else {
      Issue.record("Expected nested ordered list in second item")
      return
    }
    #expect(nestedList2.children.count == 2)

    // Check third item (simple)
    guard let item3 = ulist.children[2] as? ListItemNode else {
      Issue.record("Expected third ListItemNode")
      return
    }
    #expect(item3.children.count == 1) // just paragraph

    guard let para3 = item3.children[0] as? ParagraphNode,
          let text3 = para3.children.first as? TextNode else {
      Issue.record("Expected paragraph in third item")
      return
    }
    #expect(text3.content == "Item 3")
  }

  @Test("Multi-level nested lists")
  func multiLevelNestedLists() {
    let input = """
      1. First level
         - Second level
           - Third level
             1. Fourth level
         - Another second level
      2. First level again
      """
    let result = parser.parse(input, language: language)
    print("Parse errors: \(result.errors)")
    print("Root children count: \(result.root.children.count)")
    
    // Debug print structure
    func printNode(_ node: CodeNode<MarkdownNodeElement>, indent: String = "") {
      print("\(indent)\(type(of: node)) - element: \(node.element)")
      if let text = node as? TextNode {
        print("\(indent)  content: '\(text.content)'")
      }
      for child in node.children {
        printNode(child, indent: indent + "  ")
      }
    }
    printNode(result.root)
    
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)

    guard let olist = result.root.children[0] as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    print("Ordered list children count: \(olist.children.count)")
    #expect(olist.children.count == 2)

    // Check first item with multi-level nesting
    guard let item1 = olist.children[0] as? ListItemNode else {
      Issue.record("Expected first ListItemNode")
      return
    }
    print("First item children count: \(item1.children.count)")
  }

  @Test("Mixed list types in sequence")
  func mixedListTypes() {
    let input = """
      - Unordered item 1
      - Unordered item 2

      1. Ordered item 1
      2. Ordered item 2

      - Another unordered list
        1. With nested ordered
        2. Second nested ordered

      3. Continuing ordered list
      4. Final ordered item
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 4) // 4 separate lists

    // First unordered list
    guard let ulist1 = result.root.children[0] as? UnorderedListNode else {
      Issue.record("Expected first UnorderedListNode")
      return
    }
    #expect(ulist1.children.count == 2)

    // First ordered list
    guard let olist1 = result.root.children[1] as? OrderedListNode else {
      Issue.record("Expected first OrderedListNode")
      return
    }
    #expect(olist1.children.count == 2)

    // Second unordered list with nested ordered
    guard let ulist2 = result.root.children[2] as? UnorderedListNode else {
      Issue.record("Expected second UnorderedListNode")
      return
    }
    #expect(ulist2.children.count == 1)

    guard let item = ulist2.children[0] as? ListItemNode else {
      Issue.record("Expected ListItemNode in second unordered list")
      return
    }
    #expect(item.children.count == 2) // paragraph + nested ordered list

    guard let nestedOList = item.children[1] as? OrderedListNode else {
      Issue.record("Expected nested ordered list")
      return
    }
    #expect(nestedOList.children.count == 2)

    // Second ordered list (continuation)
    guard let olist2 = result.root.children[3] as? OrderedListNode else {
      Issue.record("Expected second OrderedListNode")
      return
    }
    #expect(olist2.children.count == 2)
  }

  @Test("List items with multiple paragraphs")
  func listItemsWithMultipleParagraphs() {
    let input = """
      1. First paragraph of item 1.

         Second paragraph of item 1.

      2. First paragraph of item 2.

         Second paragraph of item 2.
         This continues the second paragraph.
      """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)

    guard let olist = result.root.children[0] as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(olist.children.count == 2)

    // Check first item with multiple paragraphs
    guard let item1 = olist.children[0] as? ListItemNode else {
      Issue.record("Expected first ListItemNode")
      return
    }
    #expect(item1.children.count == 2) // two paragraphs

    guard let para1_1 = item1.children[0] as? ParagraphNode,
          let text1_1 = para1_1.children.first as? TextNode else {
      Issue.record("Expected first paragraph in first item")
      return
    }
    #expect(text1_1.content == "First paragraph of item 1.")

    guard let para1_2 = item1.children[1] as? ParagraphNode,
          let text1_2 = para1_2.children.first as? TextNode else {
      Issue.record("Expected second paragraph in first item")
      return
    }
    #expect(text1_2.content == "Second paragraph of item 1.")

    // Check second item with multiple paragraphs
    guard let item2 = olist.children[1] as? ListItemNode else {
      Issue.record("Expected second ListItemNode")
      return
    }
    #expect(item2.children.count == 2) // two paragraphs

    guard let para2_1 = item2.children[0] as? ParagraphNode,
          let text2_1 = para2_1.children.first as? TextNode else {
      Issue.record("Expected first paragraph in second item")
      return
    }
    #expect(text2_1.content == "First paragraph of item 2.")

    guard let para2_2 = item2.children[1] as? ParagraphNode else {
      Issue.record("Expected second paragraph in second item")
      return
    }
    // The second paragraph should contain the continuation text
    let para2_2_text = para2_2.children.compactMap { $0 as? TextNode }.map { $0.content }.joined()
    #expect(para2_2_text.contains("Second paragraph of item 2."))
    #expect(para2_2_text.contains("This continues the second paragraph."))
  }
}

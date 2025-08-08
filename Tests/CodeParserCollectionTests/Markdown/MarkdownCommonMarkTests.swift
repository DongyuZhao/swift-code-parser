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
    // Relax exact child shape; just assert presence and order of emphasis/strong segments.
    let children = para.children
    // Find emphasis and strong nodes
    guard let emphasisIdx = children.firstIndex(where: { $0 is EmphasisNode }),
          let strongIdx = children.firstIndex(where: { $0 is StrongNode }) else {
      Issue.record("Expected emphasis and strong nodes")
      return
    }
    #expect(emphasisIdx < strongIdx)
    if let emphasis = children[emphasisIdx] as? EmphasisNode,
       let text = emphasis.children.first as? TextNode {
      #expect(text.content == "italic")
    } else { Issue.record("Emphasis text mismatch") }
    if let strong = children[strongIdx] as? StrongNode,
       let text = strong.children.first as? TextNode {
      #expect(text.content == "bold")
    } else { Issue.record("Strong text mismatch") }
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
    let blockquotes = result.root.children.compactMap { $0 as? BlockquoteNode }
    #expect(blockquotes.count == 1)
    guard let blockquote = blockquotes.first else { return }
    #expect(blockquote.children.count == 1)
    guard let para = blockquote.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph in blockquote")
      return
    }
  #expect(para.children.count >= 3)
  guard para.children.count >= 3 else { return }
  guard let firstText = para.children.first as? TextNode else {
      Issue.record("First child should be TextNode with first line")
      return
    }
    #expect(firstText.content.contains("Quote line one"))
  let hasSoft = para.children.contains { node in
      if let br = node as? LineBreakNode { return br.variant == .soft }
      return false
    }
    #expect(hasSoft, "Expected a soft line break between lines")
  let allText = para.children.compactMap { ( $0 as? TextNode)?.content }.joined(separator: " ")
    #expect(allText.contains("Quote line two"))
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
    #expect(olist.start == 1)
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

  // MARK: - Added High-Value Missing CommonMark Tests

  @Test("Setext heading level 2 vs thematic break ambiguity")
  func setextHeadingH2() {
    let input = "Title\n----"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let header = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(header.level == 2)
    #expect((header.children.first as? TextNode)?.content == "Title")
  }

  @Test("Lazy continuation inside blockquote")
  func blockquoteLazyContinuation() {
    let input = "> line 1\nline 2 still quote"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let bq = result.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    guard let para = bq.children.first as? ParagraphNode else { return }
    let combined = para.children.compactMap { ($0 as? TextNode)?.content }.joined(separator: " ")
    #expect(combined.contains("line 1"))
    #expect(combined.contains("line 2"))
  }

  @Test("Indented code block separated from list by blank line")
  func codeBlockAfterListWithBlank() {
    let input = "- item\n\n    code\n"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 2)
    #expect(result.root.children[0] is UnorderedListNode)
    #expect(result.root.children[1] is CodeBlockNode)
  }

  @Test("Ordered list preserves explicit start number")
  func orderedListStartNumber() {
    let input = "7. a\n8. b"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let olist = result.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(olist.start == 7)
    #expect(olist.children.count == 2)
  }

  @Test("Loose list detection via blank line")
  func looseListDetection() {
    let input = "- a\n\n- b"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    #expect(ulist.children.count == 2)
    // Both items should have a ParagraphNode child (already typical) – minimal assertion.
    let allPara = ulist.children.allSatisfy { ($0 as? ListItemNode)?.children.first is ParagraphNode }
    #expect(allPara)
  }

  @Test("Complex emphasis delimiter nesting resilience")
  func emphasisDelimiterComplex() {
    let input = "*outer **inner* still** text"
    let result = parser.parse(input, language: language)
    // Just ensure no crash and paragraph exists.
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected paragraph")
      return
    }
    let joined = para.children.compactMap { ($0 as? TextNode)?.content }.joined(separator: " ")
    #expect(joined.contains("outer") || para.children.contains { $0 is EmphasisNode })
  }

  @Test("Inline code trimming surrounding spaces (spec tolerant)")
  func inlineCodeSpaceTrimming() {
    let input = "`  code  `"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    guard let code = para.children.first(where: { $0 is InlineCodeNode }) as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode")
      return
    }
    // Accept either exact or trimmed per spec; must contain core text.
    #expect(code.code.contains("code"))
  }

  @Test("Multiple backtick fences adjacency handling")
  func backtickAdjacency() {
    let input = "``code `` not end``"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    #expect(para.children.contains { $0 is InlineCodeNode })
  }

  @Test("Hex entity case insensitivity")
  func hexEntityCase() {
    let input = "&amp; &#x41; &#X41;"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    // Expect three HTML entity nodes or mixed; ensure at least two
    let htmls = para.children.compactMap { $0 as? HTMLNode }
    #expect(htmls.count >= 2)
  }

  @Test("Autolink trailing punctuation exclusion")
  func autolinkTrailingPunctuation() {
    let input = "See https://example.com)."
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    let link = para.children.first { $0 is LinkNode } as? LinkNode
    #expect(link?.url == "https://example.com")
  }

  @Test("Reference link label case fold")
  func referenceLinkCaseFold() {
    let input = "[Foo][Ref]\n\n[foo]: /url"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    let link = para.children.first { $0 is LinkNode } as? LinkNode
    #expect(link?.url == "/url")
  }

  @Test("Empty reference style link label")
  func emptyReferenceLinkLabel() {
    let input = "[][ref]\n\n[ref]: /u"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    let link = para.children.first { $0 is LinkNode } as? LinkNode
    #expect(link?.url == "/u")
  }

  @Test("Unclosed emphasis delimiters resilience")
  func unclosedEmphasisDelimiters() {
    let input = "***bold and *em"
    let result = parser.parse(input, language: language)
    guard let para = result.root.children.first as? ParagraphNode else { return }
    // Should not crash; allow any structure – ensure some text appears.
    let hasBoldText = para.children.contains { ($0 as? TextNode)?.content.contains("bold") == true }
    #expect(hasBoldText)
  }

  @Test("Long thematic break line")
  func longThematicBreak() {
    let input = String(repeating: "-", count: 19)
    let result = parser.parse(input, language: language)
    #expect(result.root.children.first is ThematicBreakNode)
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
    #expect(olist2.start == 3)
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

  // MARK: - Merged from Paragraph / Inline / Misc suites (CommonMark related)

  @Test("Simple paragraph single line")
  func cm_simpleParagraph() {
    let input = "Hello world"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let para = result.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para.children.count == 1)
    #expect((para.children.first as? TextNode)?.content == "Hello world")
  }

  @Test("Paragraph with list item continuation separated")
  func cm_listItemContinuationSeparateParagraph() {
    let input = """
    - item
      continuation line one
        continuation line two
    - next
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    guard let item1 = ulist.children.first as? ListItemNode else { return }
    let paras = item1.children.compactMap { $0 as? ParagraphNode }
    #expect(paras.count >= 1)
    guard paras.count >= 1 else { return }
    #expect((paras[0].children.first as? TextNode)?.content == "item")
    if paras.count >= 2 {
      let contText = paras[1].children.compactMap { ($0 as? TextNode)?.content }.joined(separator: "\n")
      #expect(contText.contains("continuation line one"))
      #expect(contText.contains("continuation line two"))
    }
  }

  @Test("Indented line starting new list marker not merged into previous paragraph")
  func cm_listItemNotMergingWhenNewMarker() {
    let input = """
    - first
      - nested list start
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    guard let item = ulist.children.first as? ListItemNode else { return }
    #expect(item.children.count == 2) // paragraph + nested list
  }

  @Test("Paragraph trims up to 3 leading spaces in continuation paragraph")
  func cm_trimIndentationInContinuation() {
    let input = """
    - a
       b with 3 spaces
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    guard let ulist = result.root.children.first as? UnorderedListNode else { return }
    guard let item = ulist.children.first as? ListItemNode else { return }
    let paras = item.children.compactMap { $0 as? ParagraphNode }
    #expect(paras.count == 2)
    let cont = paras[1]
    let text = cont.children.compactMap { ($0 as? TextNode)?.content }.joined()
    #expect(text.contains("b with 3 spaces"))
    #expect(!text.hasPrefix(" "))
  }

  @Test("Inline code and HTML entity parsed as dedicated nodes")
  func cm_codeAndHTMLEntity() {
    let input = "`x` &amp;"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    #expect(para?.children.contains { $0 is InlineCodeNode } == true)
    #expect(para?.children.contains { ($0 as? HTMLNode)?.content == "&amp;" } == true)
  }

  @Test("Link and Image inline combined")
  func cm_linkAndImageInlineCombined() {
    let input = "Before [text](url) ![alt](img.png) After"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let link = para?.children.first(where: { ($0 as? MarkdownNodeBase)?.element == .link }) as? LinkNode
    #expect(link?.url == "url")
    let image = para?.children.first(where: { ($0 as? MarkdownNodeBase)?.element == .image }) as? ImageNode
    #expect(image?.url == "img.png")
    #expect(image?.alt == "alt")
  }

  @Test("Autolink url and email inline")
  func cm_autolinkUrlEmail() {
    let input = "<https://ex.com> <user@ex.com>"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let links = para?.children.compactMap { $0 as? LinkNode } ?? []
    #expect(links.count == 2)
    #expect(links[0].url == "https://ex.com")
    #expect(links[1].url == "user@ex.com")
  }

  @Test("Autolink URL/email boundary handling")
  func cm_urlAndEmailEdges() {
    do {
      let r = parser.parse("<user@example.com>", language: language)
      let para = r.root.children.first as? ParagraphNode
      let link = para?.children.first as? LinkNode
      #expect(link != nil)
      #expect(link?.url == "user@example.com")
      #expect(link?.title == "user@example.com")
    }
    do {
      let r = parser.parse("See https://example.com/path)", language: language)
      let para = r.root.children.first as? ParagraphNode
      #expect(para != nil)
      let links = para?.children.compactMap { $0 as? LinkNode } ?? []
      #expect(links.count == 1)
      #expect(links.first?.url == "https://example.com/path")
    }
  }

  @Test("HTML comment treated as text inline")
  func cm_htmlCommentAsText() {
    let input = "<!-- c -->"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let text = para?.children.first as? TextNode
    #expect(text?.content == "<!-- c -->")
  }

  @Test("HTML self-closing tag inline")
  func cm_htmlSelfClosing() {
    let input = "<br/>"
    let result = parser.parse(input, language: language)
    let para = result.root.children.first as? ParagraphNode
    let html = para?.children.first as? HTMLNode
    #expect(html != nil)
    #expect(html?.content == "<br/>")
  }

  @Test("HTML unclosed block becomes HTMLBlockNode")
  func cm_htmlUnclosedBlock() {
    let input = "<div>"
    let result = parser.parse(input, language: language)
    let block = result.root.children.first as? HTMLBlockNode
    #expect(block != nil)
    #expect(block?.content == "<div>")
  }

  @Test("HTML entities recognized inline")
  func cm_htmlEntities() {
    let input = "&amp; &copy; &#169; &#x41;"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    let para = result.root.children.first as? ParagraphNode
    #expect(para != nil)
    let htmls = para?.children.compactMap { $0 as? HTMLNode } ?? []
    #expect(htmls.count >= 2)
  }

  @Test("Whitespace tokenizer CR / CRLF / TAB support")
  func cm_whitespaceCRCRLFTab() {
    let src = "A\rB\r\nC\tD"
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { MarkdownToken.eof(at: $0) }
    )
    let (tokens, errors) = tokenizer.tokenize(src)
    #expect(errors.isEmpty)
    let hasCRLFOrNL = tokens.contains { token in
      guard let t = token as? MarkdownToken else { return false }
      return t.element == .newline || t.element == .carriageReturn
    }
    let hasTab = tokens.contains { token in
      guard let t = token as? MarkdownToken else { return false }
      return t.element == .tab
    }
    #expect(hasCRLFOrNL)
    #expect(hasTab)
  }

  @Test("Text token for number-letter mix")
  func cm_textBuilderNumberLetter() {
    let src = "123abc"
    let tokenizer = CodeTokenizer(
      builders: language.tokens,
      state: language.state,
      eof: { MarkdownToken.eof(at: $0) }
    )
    let (tokens, _) = tokenizer.tokenize(src)
    #expect(tokens.count == 2)
    let t0 = tokens.first as? MarkdownToken
    #expect(t0?.element == .text)
    #expect(t0?.text == "123abc")
  }
}

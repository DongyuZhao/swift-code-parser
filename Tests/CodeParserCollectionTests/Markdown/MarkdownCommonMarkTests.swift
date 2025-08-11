import Foundation
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

  // MARK: - CommonMark Spec Test Cases

  /// Represents a single CommonMark specification test case
  struct CommonMarkTestCase: Codable {
    let markdown: String
    let html: String
    let example: Int
    let startLine: Int
    let endLine: Int
    let section: String

    enum CodingKeys: String, CodingKey {
      case markdown, html, example
      case startLine = "start_line"
      case endLine = "end_line"
      case section
    }
  }

  // MARK: - CommonMark Critical Feature Tests (Strict Validation)

  @Test("CommonMark Spec - Tabs handling (Strict)")
  func commonMarkTabs() {
    // Example 1: Tab at start becomes code block with exact content
    let input1 = "\tfoo\tbaz\t\tbim\n"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let codeBlock1 = result1.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode as first child")
      return
    }
    #expect(codeBlock1.source == "foo\tbaz\t\tbim", "Code block content should preserve tabs")
    #expect(
      codeBlock1.language == nil || codeBlock1.language?.isEmpty == true,
      "Code block should have no language")

    // Example 2: Spaces + tab becomes code block
    let input2 = "  \tfoo\tbaz\t\tbim\n"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 1, "Should have exactly one child")
    guard let codeBlock2 = result2.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode as first child")
      return
    }
    #expect(
      codeBlock2.source == "foo\tbaz\t\tbim",
      "Code block content should preserve tabs and strip leading indent")
  }

  @Test("CommonMark Spec - ATX Headings (Strict)")
  func commonMarkATXHeadings() {
    // Test various heading levels with exact structure validation
    for level in 1...6 {
      let input = String(repeating: "#", count: level) + " Heading Level \(level)"
      let result = parser.parse(input, language: language)
      #expect(result.errors.isEmpty, "Should parse without errors for level \(level)")
      #expect(result.root.children.count == 1, "Should have exactly one child for level \(level)")

      guard let heading = result.root.children.first as? HeaderNode else {
        Issue.record("Expected HeaderNode as first child for level \(level)")
        continue
      }
      #expect(heading.level == level, "Heading level should be exactly \(level)")
      #expect(heading.children.count == 1, "Heading should have exactly one text child")

      guard let textNode = heading.children.first as? TextNode else {
        Issue.record("Expected TextNode as heading child for level \(level)")
        continue
      }
      #expect(textNode.content == "Heading Level \(level)", "Text content should match exactly")
    }

    // Test heading with trailing hashes (should be stripped)
    let input = "# Heading #"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty, "Should parse without errors")
    #expect(result.root.children.count == 1, "Should have exactly one child")
    guard let heading = result.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode")
      return
    }
    #expect(heading.level == 1, "Should be level 1 heading")
    guard let textNode = heading.children.first as? TextNode else {
      Issue.record("Expected TextNode in heading")
      return
    }
    #expect(textNode.content == "Heading", "Trailing hashes should be stripped")
  }

  @Test("CommonMark Spec - Setext Headings (Strict)")
  func commonMarkSetextHeadings() {
    // Level 1 setext heading
    let input1 = "Heading Level 1\n==============="
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let heading1 = result1.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode for setext level 1")
      return
    }
    #expect(heading1.level == 1, "Should be level 1 heading")
    guard let text1 = heading1.children.first as? TextNode else {
      Issue.record("Expected TextNode in setext heading")
      return
    }
    #expect(text1.content == "Heading Level 1", "Text should match exactly")

    // Level 2 setext heading
    let input2 = "Heading Level 2\n---------------"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 1, "Should have exactly one child")
    guard let heading2 = result2.root.children.first as? HeaderNode else {
      Issue.record("Expected HeaderNode for setext level 2")
      return
    }
    #expect(heading2.level == 2, "Should be level 2 heading")
    guard let text2 = heading2.children.first as? TextNode else {
      Issue.record("Expected TextNode in setext heading")
      return
    }
    #expect(text2.content == "Heading Level 2", "Text should match exactly")
  }

  @Test("CommonMark Spec - Thematic Breaks (Strict)")
  func commonMarkThematicBreaks() {
    let validInputs = [
      "---",
      "***",
      "___",
      "- - -",
      "* * *",
      "_ _ _",
      String(repeating: "-", count: 10),
      "   ---   ",  // with leading/trailing spaces
    ]

    for input in validInputs {
      let result = parser.parse(input, language: language)
      #expect(result.errors.isEmpty, "Should parse without errors for: '\(input)'")
      #expect(result.root.children.count == 1, "Should have exactly one child for: '\(input)'")
      #expect(
        result.root.children.first is ThematicBreakNode,
        "Should be ThematicBreakNode for: '\(input)'")
    }

    // Test invalid cases that should NOT create thematic breaks
    let invalidInputs = [
      "--",  // too few characters
      "- -",  // too few characters with spaces
      "----a",  // text after
    ]

    for input in invalidInputs {
      let result = parser.parse(input, language: language)
      #expect(result.errors.isEmpty, "Should parse without errors for invalid: '\(input)'")
      let hasThematicBreak = result.root.children.contains { $0 is ThematicBreakNode }
      #expect(!hasThematicBreak, "Should NOT create thematic break for invalid: '\(input)'")
    }
  }

  @Test("CommonMark Spec - Fenced Code Blocks (Strict)")
  func commonMarkFencedCodeBlocks() {
    // Basic fenced code block with backticks
    let input1 = "```\ncode line 1\ncode line 2\n```"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let codeBlock1 = result1.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    #expect(codeBlock1.source == "code line 1\ncode line 2", "Should preserve exact code content")
    #expect(
      codeBlock1.language == nil || codeBlock1.language?.isEmpty == true, "Should have no language")

    // Fenced code block with language
    let input2 = "```swift\nlet x = 1\nlet y = 2\n```"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 1, "Should have exactly one child")
    guard let codeBlock2 = result2.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode with language")
      return
    }
    #expect(codeBlock2.language == "swift", "Should preserve language info")
    #expect(codeBlock2.source == "let x = 1\nlet y = 2", "Should preserve exact code content")

    // CRITICAL: Fenced code block with TILDES (~~~)
    let input3 = "~~~python\nprint('hello world')\nprint('second line')\n~~~"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse tilde fences without errors")
    guard let codeBlock3 = result3.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode with tilde fences")
      return
    }
    #expect(codeBlock3.language == "python", "Should preserve python language")
    #expect(
      codeBlock3.source == "print('hello world')\nprint('second line')",
      "Should preserve tilde fence content")

    // Fenced code block with info string
    let input4 = "```javascript {.line-numbers}\nconsole.log('test');\n```"
    let result4 = parser.parse(input4, language: language)
    #expect(result4.errors.isEmpty, "Should parse with info string")
    guard let codeBlock4 = result4.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode with info string")
      return
    }
    #expect(codeBlock4.language == "javascript", "Should extract language from info string")

    // Test minimum fence length (3 backticks)
    let input5 = "``\ncode\n``"
    let result5 = parser.parse(input5, language: language)
    #expect(result5.errors.isEmpty, "Should parse without errors")
    // This should NOT create a code block (too few backticks)
    let hasCodeBlock5 = result5.root.children.contains { $0 is CodeBlockNode }
    #expect(!hasCodeBlock5, "Should NOT create code block with only 2 backticks")
  }

  @Test("CommonMark Spec - Indented Code Blocks (Strict)")
  func commonMarkIndentedCodeBlocks() {
    let input = "    code line 1\n    code line 2\n    \n    code line 4"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty, "Should parse without errors")
    #expect(result.root.children.count == 1, "Should have exactly one child")
    guard let codeBlock = result.root.children.first as? CodeBlockNode else {
      Issue.record("Expected CodeBlockNode")
      return
    }
    // Should strip 4 spaces from each line and preserve empty lines
    let expectedContent = "code line 1\ncode line 2\n\ncode line 4"
    #expect(
      codeBlock.source == expectedContent, "Should strip exactly 4 spaces and preserve structure")
    #expect(
      codeBlock.language == nil || codeBlock.language?.isEmpty == true,
      "Indented code blocks have no language")
  }

  @Test("CommonMark Spec - Block Quotes (Strict)")
  func commonMarkBlockQuotes() {
    // Simple blockquote
    let input1 = "> This is a quote"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let blockquote1 = result1.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode")
      return
    }
    #expect(blockquote1.children.count == 1, "Blockquote should have exactly one paragraph")
    guard let para1 = blockquote1.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in blockquote")
      return
    }
    #expect(para1.children.count == 1, "Paragraph should have exactly one text node")
    guard let text1 = para1.children.first as? TextNode else {
      Issue.record("Expected TextNode in paragraph")
      return
    }
    #expect(text1.content == "This is a quote", "Text content should match exactly")

    // Multi-line blockquote
    let input2 = "> Line 1\n> Line 2"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 1, "Should have exactly one blockquote")
    guard let blockquote2 = result2.root.children.first as? BlockquoteNode else {
      Issue.record("Expected BlockquoteNode for multi-line")
      return
    }
    #expect(blockquote2.children.count == 1, "Should have exactly one paragraph")
    guard let para2 = blockquote2.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode in multi-line blockquote")
      return
    }

    // Should contain both lines with soft line break
    let textNodes = para2.children.compactMap { $0 as? TextNode }
    let allText = textNodes.map { $0.content }.joined()
    #expect(allText.contains("Line 1"), "Should contain first line")
    #expect(allText.contains("Line 2"), "Should contain second line")
  }

  @Test("CommonMark Spec - Lists (Strict)")
  func commonMarkLists() {
    // Unordered list with exact structure
    let input1 = "- Item 1\n- Item 2\n- Item 3"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let ulist = result1.root.children.first as? UnorderedListNode else {
      Issue.record("Expected UnorderedListNode")
      return
    }
    #expect(ulist.children.count == 3, "Should have exactly 3 list items")

    for (index, child) in ulist.children.enumerated() {
      guard let listItem = child as? ListItemNode else {
        Issue.record("Expected ListItemNode at index \(index)")
        continue
      }
      #expect(listItem.children.count == 1, "List item should have exactly one paragraph")
      guard let para = listItem.children.first as? ParagraphNode else {
        Issue.record("Expected ParagraphNode in list item \(index)")
        continue
      }
      #expect(para.children.count == 1, "Paragraph should have exactly one text node")
      guard let text = para.children.first as? TextNode else {
        Issue.record("Expected TextNode in paragraph for item \(index)")
        continue
      }
      #expect(text.content == "Item \(index + 1)", "Text should match expected content")
    }

    // Ordered list with custom start
    let input2 = "7. Item 7\n8. Item 8\n9. Item 9"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 1, "Should have exactly one child")
    guard let olist = result2.root.children.first as? OrderedListNode else {
      Issue.record("Expected OrderedListNode")
      return
    }
    #expect(olist.start == 7, "Should start at 7")
    #expect(olist.children.count == 3, "Should have exactly 3 list items")

    for (index, child) in olist.children.enumerated() {
      guard let listItem = child as? ListItemNode else {
        Issue.record("Expected ListItemNode at index \(index)")
        continue
      }
      guard let para = listItem.children.first as? ParagraphNode,
        let text = para.children.first as? TextNode
      else {
        Issue.record("Expected paragraph with text in ordered list item \(index)")
        continue
      }
      #expect(text.content == "Item \(7 + index)", "Text should match expected content")
    }
  }

  @Test("CommonMark Spec - Emphasis and Strong (Strict)")
  func commonMarkEmphasisStrong() {
    // Simple emphasis with asterisks
    let input1 = "This is *emphasized* text."
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one paragraph")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 3, "Should have text, emphasis, text")
    #expect((para1.children[0] as? TextNode)?.content == "This is ", "First text should match")
    guard let emphasis = para1.children[1] as? EmphasisNode else {
      Issue.record("Expected EmphasisNode at position 1")
      return
    }
    #expect(emphasis.children.count == 1, "Emphasis should have exactly one child")
    #expect(
      (emphasis.children[0] as? TextNode)?.content == "emphasized", "Emphasis text should match")
    #expect((para1.children[2] as? TextNode)?.content == " text.", "Last text should match")

    // Strong emphasis with asterisks
    let input2 = "This is **strong** text."
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    guard let para2 = result2.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for strong")
      return
    }
    #expect(para2.children.count == 3, "Should have text, strong, text")
    guard let strong = para2.children[1] as? StrongNode else {
      Issue.record("Expected StrongNode at position 1")
      return
    }
    #expect(strong.children.count == 1, "Strong should have exactly one child")
    #expect((strong.children[0] as? TextNode)?.content == "strong", "Strong text should match")

    // Intraword underscores should NOT create emphasis
    let input3 = "foo_bar_baz"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse without errors")
    guard let para3 = result3.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for intraword")
      return
    }
    #expect(para3.children.count == 1, "Should have exactly one text node")
    #expect(
      (para3.children[0] as? TextNode)?.content == "foo_bar_baz", "Should preserve underscores")

    // CRITICAL: Triple asterisks (***strong emphasis***)
    let input4 = "This is ***both strong and emphasized*** text."
    let result4 = parser.parse(input4, language: language)
    #expect(result4.errors.isEmpty, "Should parse triple asterisks without errors")
    guard result4.root.children.first is ParagraphNode else {
      Issue.record("Expected ParagraphNode for triple asterisks")
      return
    }
    // Should have nested strong and emphasis nodes
    let strongNodes4 = findNodes(in: result4.root, ofType: StrongNode.self)
    let emphasisNodes4 = findNodes(in: result4.root, ofType: EmphasisNode.self)
    #expect(strongNodes4.count >= 1, "Should have at least one strong node for triple asterisks")
    #expect(
      emphasisNodes4.count >= 1, "Should have at least one emphasis node for triple asterisks")

    // CRITICAL: Triple underscores (___strong emphasis___)
    let input5 = "This is ___both strong and emphasized___ text."
    let result5 = parser.parse(input5, language: language)
    #expect(result5.errors.isEmpty, "Should parse triple underscores without errors")
    guard result5.root.children.first is ParagraphNode else {
      Issue.record("Expected ParagraphNode for triple underscores")
      return
    }
    let strongNodes5 = findNodes(in: result5.root, ofType: StrongNode.self)
    let emphasisNodes5 = findNodes(in: result5.root, ofType: EmphasisNode.self)
    #expect(strongNodes5.count >= 1, "Should have at least one strong node for triple underscores")
    #expect(
      emphasisNodes5.count >= 1, "Should have at least one emphasis node for triple underscores")

    // Nested emphasis within strong
    let input6 = "**This is *nested* emphasis**"
    let result6 = parser.parse(input6, language: language)
    #expect(result6.errors.isEmpty, "Should parse nested emphasis without errors")
    let strongNodes6 = findNodes(in: result6.root, ofType: StrongNode.self)
    let emphasisNodes6 = findNodes(in: result6.root, ofType: EmphasisNode.self)
    #expect(strongNodes6.count == 1, "Should have exactly one strong node")
    #expect(emphasisNodes6.count == 1, "Should have exactly one emphasis node")
  }

  @Test("CommonMark Spec - Links (Strict)")
  func commonMarkLinks() {
    // Inline link with exact structure
    let input1 = "Visit [GitHub](https://github.com) for code."
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one paragraph")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 3, "Should have text, link, text")
    #expect((para1.children[0] as? TextNode)?.content == "Visit ", "First text should match")
    guard let link = para1.children[1] as? LinkNode else {
      Issue.record("Expected LinkNode at position 1")
      return
    }
    #expect(link.url == "https://github.com", "Link URL should match exactly")
    #expect(link.children.count == 1, "Link should have exactly one child")
    #expect((link.children[0] as? TextNode)?.content == "GitHub", "Link text should match")
    #expect((para1.children[2] as? TextNode)?.content == " for code.", "Last text should match")

    // Reference link
    let input2 = "Visit [GitHub][gh] for code.\n\n[gh]: https://github.com \"GitHub\""
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    // Should have paragraph and reference definition
    let links = findNodes(in: result2.root, ofType: LinkNode.self)
    #expect(links.count == 1, "Should have exactly one link")
    if let link = links.first {
      #expect(link.url == "https://github.com", "Reference link URL should resolve")
      #expect(link.title == "GitHub", "Reference link title should resolve")
    }

    // Autolink
    let input3 = "Visit <https://github.com> now."
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse without errors")
    guard let para3 = result3.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for autolink")
      return
    }
    let autoLinks = para3.children.compactMap { $0 as? LinkNode }
    #expect(autoLinks.count == 1, "Should have exactly one autolink")
    if let autoLink = autoLinks.first {
      #expect(autoLink.url == "https://github.com", "Autolink URL should match")
    }
  }

  @Test("CommonMark Spec - Images (Strict)")
  func commonMarkImages() {
    // Inline image with exact structure
    let input1 = "See ![Alt text](image.png) here."
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one paragraph")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 3, "Should have text, image, text")
    #expect((para1.children[0] as? TextNode)?.content == "See ", "First text should match")
    guard let image = para1.children[1] as? ImageNode else {
      Issue.record("Expected ImageNode at position 1")
      return
    }
    #expect(image.url == "image.png", "Image URL should match exactly")
    #expect(image.alt == "Alt text", "Image alt text should match exactly")
    #expect((para1.children[2] as? TextNode)?.content == " here.", "Last text should match")

    // CRITICAL: Reference-style image
    let input2 = "See ![Alt text][img] here.\n\n[img]: image.png \"Image Title\""
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse reference image without errors")
    // Should resolve the reference
    let images = findNodes(in: result2.root, ofType: ImageNode.self)
    #expect(images.count == 1, "Should have exactly one image")
    if let refImage = images.first {
      #expect(refImage.url == "image.png", "Reference image URL should resolve")
      #expect(refImage.alt == "Alt text", "Reference image alt should match")
      #expect(refImage.title == "Image Title", "Reference image title should resolve")
    }

    // Image with title
    let input3 = "![Alt text](image.png \"Image Title\")"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse image with title")
    let images3 = findNodes(in: result3.root, ofType: ImageNode.self)
    #expect(images3.count == 1, "Should have exactly one image with title")
    if let imageWithTitle = images3.first {
      #expect(imageWithTitle.title == "Image Title", "Should preserve image title")
    }
  }

  @Test("CommonMark Spec - Code Spans (Strict)")
  func commonMarkCodeSpans() {
    // Simple code span
    let input1 = "Use `code` in text."
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 3, "Should have text, code, text")
    #expect((para1.children[0] as? TextNode)?.content == "Use ", "First text should match")
    guard let code = para1.children[1] as? InlineCodeNode else {
      Issue.record("Expected InlineCodeNode at position 1")
      return
    }
    #expect(code.code == "code", "Code content should match exactly")
    #expect((para1.children[2] as? TextNode)?.content == " in text.", "Last text should match")

    // Code span with backticks inside
    let input2 = "Use `` code with `backtick` `` here."
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    guard let para2 = result2.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for complex code")
      return
    }
    let codes = para2.children.compactMap { $0 as? InlineCodeNode }
    #expect(codes.count == 1, "Should have exactly one code span")
    if let code = codes.first {
      #expect(
        code.code == " code with `backtick` ", "Should preserve internal backticks and spaces")
    }
  }

  @Test("CommonMark Spec - Paragraphs (Strict)")
  func commonMarkParagraphs() {
    // Single paragraph
    let input1 = "This is a paragraph."
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    #expect(result1.root.children.count == 1, "Should have exactly one child")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 1, "Should have exactly one text node")
    #expect(
      (para1.children[0] as? TextNode)?.content == "This is a paragraph.",
      "Text should match exactly")

    // Multiple paragraphs separated by blank line
    let input2 = "Paragraph 1.\n\nParagraph 2."
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    #expect(result2.root.children.count == 2, "Should have exactly two paragraphs")
    guard let para2_1 = result2.root.children[0] as? ParagraphNode,
      let para2_2 = result2.root.children[1] as? ParagraphNode
    else {
      Issue.record("Expected two ParagraphNodes")
      return
    }
    #expect(
      (para2_1.children[0] as? TextNode)?.content == "Paragraph 1.", "First paragraph should match")
    #expect(
      (para2_2.children[0] as? TextNode)?.content == "Paragraph 2.", "Second paragraph should match"
    )

    // Paragraph with soft line break
    let input3 = "Line 1\nLine 2"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse without errors")
    #expect(result3.root.children.count == 1, "Should have exactly one paragraph")
    guard let para3 = result3.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for soft break")
      return
    }
    // Should contain both lines connected by soft line break
    let textNodes = para3.children.compactMap { $0 as? TextNode }
    let allText = textNodes.map { $0.content }.joined()
    #expect(allText.contains("Line 1"), "Should contain first line")
    #expect(allText.contains("Line 2"), "Should contain second line")
  }

  @Test("CommonMark Spec - Line Breaks (Strict)")
  func commonMarkLineBreaks() {
    // CRITICAL: Hard line break with backslash
    let input1 = "Line 1\\\nLine 2"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let lineBreaks1 = para1.children.compactMap { $0 as? LineBreakNode }
    #expect(lineBreaks1.count == 1, "Should have exactly one line break")
    if let lineBreak = lineBreaks1.first {
      #expect(lineBreak.variant == .hard, "Should be hard line break")
    }

    // CRITICAL: Hard line break with trailing spaces (2 or more spaces)
    let input2 = "Line 1  \nLine 2"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    guard let para2 = result2.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for trailing spaces")
      return
    }
    let lineBreaks2 = para2.children.compactMap { $0 as? LineBreakNode }
    #expect(lineBreaks2.count == 1, "Should have exactly one line break with spaces")
    if let lineBreak = lineBreaks2.first {
      #expect(lineBreak.variant == .hard, "Should be hard line break with spaces")
    }

    // CRITICAL: Hard line break with more than 2 trailing spaces
    let input3 = "Line 1   \nLine 2"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse multiple trailing spaces")
    guard let para3 = result3.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for multiple spaces")
      return
    }
    let lineBreaks3 = para3.children.compactMap { $0 as? LineBreakNode }
    #expect(lineBreaks3.count == 1, "Should have line break with multiple spaces")
    if let lineBreak = lineBreaks3.first {
      #expect(lineBreak.variant == .hard, "Should be hard line break with multiple spaces")
    }

    // Soft line break (normal newline without backslash or trailing spaces)
    let input4 = "Line 1\nLine 2"
    let result4 = parser.parse(input4, language: language)
    #expect(result4.errors.isEmpty, "Should parse soft line break")
    guard let para4 = result4.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for soft break")
      return
    }
    // Should be in same paragraph with soft line break
    let textNodes4 = para4.children.compactMap { $0 as? TextNode }
    let allText4 = textNodes4.map { $0.content }.joined()
    #expect(allText4.contains("Line 1"), "Should contain first line")
    #expect(allText4.contains("Line 2"), "Should contain second line")

    // Should NOT be hard line break with only one trailing space
    let input5 = "Line 1 \nLine 2"
    let result5 = parser.parse(input5, language: language)
    #expect(result5.errors.isEmpty, "Should parse single trailing space")
    guard let para5 = result5.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for single space")
      return
    }
    let hardBreaks5 = para5.children.compactMap { $0 as? LineBreakNode }.filter {
      $0.variant == .hard
    }
    #expect(hardBreaks5.isEmpty, "Should NOT create hard break with single trailing space")
  }

  @Test("CommonMark Spec - Entity References (Strict)")
  func commonMarkEntityReferences() {
    // Named entities
    let input1 = "AT&amp;T uses &lt;brackets&gt;"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    let htmlNodes = para1.children.compactMap { $0 as? HTMLNode }
    #expect(htmlNodes.count >= 3, "Should have at least 3 HTML entities")

    // Numeric entities
    let input2 = "A is &#65; and &#x41;"
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse without errors")
    guard let para2 = result2.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode for numeric entities")
      return
    }
    let numericEntities = para2.children.compactMap { $0 as? HTMLNode }
    #expect(numericEntities.count >= 2, "Should have at least 2 numeric entities")
  }

  @Test("CommonMark Spec - Backslash Escapes (Strict)")
  func commonMarkBackslashEscapes() {
    // Escaped punctuation
    let input1 = "\\*not emphasized\\*"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse without errors")
    guard let para1 = result1.root.children.first as? ParagraphNode else {
      Issue.record("Expected ParagraphNode")
      return
    }
    #expect(para1.children.count == 1, "Should have exactly one text node")
    #expect(
      (para1.children[0] as? TextNode)?.content == "*not emphasized*", "Should escape asterisks")

    // Should NOT have emphasis nodes
    let emphasisNodes = para1.children.compactMap { $0 as? EmphasisNode }
    #expect(emphasisNodes.isEmpty, "Should not create emphasis when escaped")
  }

  @Test("CommonMark Spec - HTML Blocks and Inline HTML (Strict)")
  func commonMarkHTML() {
    // CRITICAL: HTML Block (should be recognized as block-level)
    let input1 = "<div>\n<p>HTML content</p>\n</div>"
    let result1 = parser.parse(input1, language: language)
    #expect(result1.errors.isEmpty, "Should parse HTML block without errors")
    // Should create HTML block node
    let htmlBlocks = findNodes(in: result1.root, ofType: HTMLBlockNode.self)
    #expect(htmlBlocks.count == 1, "Should have exactly one HTML block")
    if let htmlBlock = htmlBlocks.first {
      #expect(
        htmlBlock.content == "<div>\n<p>HTML content</p>\n</div>",
        "Should preserve HTML block content")
    }

    // CRITICAL: Inline HTML (within paragraph) -> expect a SINGLE HTMLNode containing opening & closing tag plus inner content
    let input2 = "This has <em>inline HTML</em> tags."
    let result2 = parser.parse(input2, language: language)
    #expect(result2.errors.isEmpty, "Should parse inline HTML without errors")
    if let para2 = result2.root.children.first as? ParagraphNode {
      // Expect text, HTMLNode, text (len == 3) OR fallback containing at least one HTMLNode
      let htmlChildren = para2.children.compactMap { $0 as? HTMLNode }
      #expect(!htmlChildren.isEmpty, "Should have one HTMLNode for inline HTML span")
      if htmlChildren.count == 1 {
        #expect(
          htmlChildren[0].content == "<em>inline HTML</em>", "Inline HTML should match exactly")
      }
    } else {
      Issue.record("Expected ParagraphNode for inline HTML")
    }

    // HTML comments -> single HTML block, inline HTML node, or dedicated CommentNode
    let input3 = "<!-- This is a comment -->"
    let result3 = parser.parse(input3, language: language)
    #expect(result3.errors.isEmpty, "Should parse HTML comments without errors")
    let commentBlocks = findNodes(in: result3.root, ofType: HTMLBlockNode.self)
    let commentInlines = findNodes(in: result3.root, ofType: HTMLNode.self)
    let commentNodes = findNodes(in: result3.root, ofType: CommentNode.self)
    #expect(
      !commentBlocks.isEmpty || !commentInlines.isEmpty || !commentNodes.isEmpty,
      "Should have a node representing the HTML comment")

    // Self-closing HTML tags -> single HTMLNode for the tag
    let input4 = "Line break: <br/> here."
    let result4 = parser.parse(input4, language: language)
    #expect(result4.errors.isEmpty, "Should parse self-closing tags")
    if let para4 = result4.root.children.first as? ParagraphNode {
      let brNodes = para4.children.compactMap { $0 as? HTMLNode }.filter {
        $0.content.contains("<br/>")
      }
      #expect(!brNodes.isEmpty, "Should have one HTMLNode for <br/>")
    } else {
      Issue.record("Expected ParagraphNode for self-closing tags")
    }

    // HTML attributes (anchor) -> single HTMLNode allowed either as direct child (paragraph) or block
    let input5 = "<a href=\"https://example.com\" class=\"link\">Link</a>"
    let result5 = parser.parse(input5, language: language)
    #expect(result5.errors.isEmpty, "Should parse HTML with attributes")
    if let para5 = result5.root.children.first as? ParagraphNode {
      let anchorNodes = para5.children.compactMap { $0 as? HTMLNode }
      #expect(anchorNodes.count == 1, "Anchor should be a single HTMLNode in paragraph")
      if let anchor = anchorNodes.first {
        #expect(
          anchor.content == "<a href=\"https://example.com\" class=\"link\">Link</a>",
          "Anchor HTML should match exactly")
      }
    } else if let block = result5.root.children.first as? HTMLBlockNode {
      #expect(
        block.content == "<a href=\"https://example.com\" class=\"link\">Link</a>",
        "Anchor HTML should match exactly")
    } else {
      Issue.record("Expected ParagraphNode or HTMLBlockNode for HTML attributes")
    }
  }

  /// Helper function to find all nodes of a specific type in the AST
  private func findNodes<T: CodeNode<MarkdownNodeElement>>(
    in root: CodeNode<MarkdownNodeElement>, ofType type: T.Type
  ) -> [T] {
    var result: [T] = []

    func traverse(_ node: CodeNode<MarkdownNodeElement>) {
      if let typedNode = node as? T {
        result.append(typedNode)
      }
      for child in node.children {
        traverse(child)
      }
    }

    traverse(root)
    return result
  }
}

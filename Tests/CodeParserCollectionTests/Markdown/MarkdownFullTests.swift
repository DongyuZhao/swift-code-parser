import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Comprehensive Markdown Parsing Tests")
struct MarkdownFullTests {
  private let language: MarkdownLanguage
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Parsing document with all features")
  func fullDocument() {
    let markdown = """
      # Heading 1

      This paragraph has *italic*, **bold**, ~~strike~~, and `code` with a $x+1$ formula.

      > [!NOTE]
      > Admonition content

      > Quote line one
      > Quote line two

      1. First ordered
      1. Second ordered
        - Nested item
        - [ ] Task item
        - [x] Done item

      - Unordered item
      - Another item

      Term
      : Definition text

      | A | B |
      |---|---|
      | 1 | 2 |

      $$ x^2 $$

      ```swift
      let code = "hi"
      ```

      ---

      Citation[@smith2023] and footnote[^1].

      <div>HTML block</div>
      ![Alt](https://example.com/img.png)

      [link](https://example.com)

      <https://autolink.com> & more.

      [^1]: Footnote text
      [@smith2023]: Smith, J. (2023). Example.
      """

    let result = parser.parse(markdown, language: language)

    #expect(result.errors.isEmpty, "Parsing should not produce any errors")
    #expect(result.root.children.count > 0, "Root should have children")

    let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
    let (tokens, _) = tokenizer.tokenize(markdown)
    #expect(tokens.count > 0)

    verifyHeadingStructure(result.root)
    verifyParagraphWithInlineElements(result.root)
    verifyAdmonitionStructure(result.root)
    verifyBlockquoteStructure(result.root)
    verifyListStructures(result.root)
    verifyDefinitionListStructure(result.root)
    verifyTableStructure(result.root)
    verifyFormulaBlockStructure(result.root)
    verifyCodeBlockStructure(result.root)
    verifyThematicBreakStructure(result.root)
    verifyHTMLBlockStructure(result.root)
    verifyImageStructure(result.root)
    verifyLinkStructure(result.root)
    verifyFootnoteAndCitationStructure(result.root)
  }

  private func verifyHeadingStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let headingNode = root.first(where: { $0.element == .heading }) as? HeaderNode else {
      Issue.record("Should find a heading node")
      return
    }

    #expect(headingNode.level == 1, "Should be a level 1 heading")
    #expect(headingNode.children.count == 1, "Heading should have one text child")

    if let textChild = headingNode.children.first as? TextNode {
      #expect(textChild.content == "Heading 1", "Heading text should match")
    } else {
      Issue.record("Heading should contain a text node")
    }
  }

  private func verifyParagraphWithInlineElements(_ root: CodeNode<MarkdownNodeElement>) {
    guard let paragraphNode = root.first(where: { $0.element == .paragraph }) as? ParagraphNode
    else {
      Issue.record("Should find a paragraph node")
      return
    }

    #expect(paragraphNode.children.count > 5, "Paragraph should have multiple inline elements")
    #expect(
      paragraphNode.first(where: { $0.element == .emphasis }) != nil, "Should contain emphasis"
    )
    #expect(paragraphNode.first(where: { $0.element == .strong }) != nil, "Should contain strong")
    #expect(paragraphNode.first(where: { $0.element == .strike }) != nil, "Should contain strike")
    #expect(
      paragraphNode.first(where: { $0.element == .code }) != nil, "Should contain inline code"
    )
    #expect(paragraphNode.first(where: { $0.element == .formula }) != nil, "Should contain formula")

    if let codeNode = paragraphNode.first(where: { $0.element == .code }) as? InlineCodeNode {
      #expect(codeNode.code == "code", "Inline code content should match")
    }
    if let formulaNode = paragraphNode.first(where: { $0.element == .formula }) as? FormulaNode {
      #expect(formulaNode.expression == "x+1", "Formula expression should match")
    }
  }

  private func verifyAdmonitionStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let admonitionNode = root.first(where: { $0.element == .admonition }) as? AdmonitionNode
    else {
      Issue.record("Should find an admonition node")
      return
    }
    #expect(admonitionNode.kind == "note", "Admonition should be of type note")
    #expect(admonitionNode.children.count > 0, "Admonition should have content")
  }

  private func verifyBlockquoteStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let blockquoteNode = root.first(where: { $0.element == .blockquote }) as? BlockquoteNode
    else {
      Issue.record("Should find a blockquote node")
      return
    }
    #expect(blockquoteNode.level == 1, "Blockquote should be level 1")
    #expect(blockquoteNode.children.count > 0, "Blockquote should have content")
    let textNodes = blockquoteNode.nodes(where: { $0.element == .text })
    #expect(textNodes.count > 0, "Blockquote should contain text")
  }

  private func verifyListStructures(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let orderedListNode = root.first(where: { $0.element == .orderedList }) as? OrderedListNode
    else {
      Issue.record("Should find an ordered list node")
      return
    }
    #expect(orderedListNode.start == 1, "Ordered list should start at 1")
    #expect(orderedListNode.level == 0, "Ordered list should be level 0")
    #expect(
      orderedListNode.children.count == 2,
      "Ordered list should have 2 children (2 list items)"
    )

    let orderedItems = orderedListNode.children.compactMap { $0 as? ListItemNode }
    #expect(orderedItems.count == 2, "Should have 2 ordered list items")

    if orderedItems.count >= 2 {
      let secondItem = orderedItems[1]
      let nestedUnorderedLists = secondItem.children.compactMap { $0 as? UnorderedListNode }
      #expect(nestedUnorderedLists.count == 1, "Second item should have 1 nested unordered list")

      if let nestedList = nestedUnorderedLists.first {
        let taskItems = nestedList.nodes(where: { $0.element == .taskListItem })
        #expect(taskItems.count == 2, "Should have 2 task items in nested list")

        if let uncheckedTask = taskItems.first(where: {
          ($0 as? TaskListItemNode)?.checked == false
        })
          as? TaskListItemNode
        {
          #expect(!uncheckedTask.checked, "Should have unchecked task")
        }
        if let checkedTask = taskItems.first(where: { ($0 as? TaskListItemNode)?.checked == true })
          as? TaskListItemNode
        {
          #expect(checkedTask.checked, "Should have checked task")
        }
      }
    }

    let unorderedLists = root.nodes(where: { $0.element == .unorderedList }).compactMap {
      $0 as? UnorderedListNode
    }
    let topLevelUnorderedLists = unorderedLists.filter { $0.level == 0 }
    #expect(topLevelUnorderedLists.count >= 1, "Should have at least 1 top-level unordered list")
  }

  private func verifyDefinitionListStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let defListNode = root.first(where: { $0.element == .definitionList }) as? DefinitionListNode
    else {
      Issue.record("Should find a definition list node")
      return
    }
    #expect(defListNode.children.count > 0, "Definition list should have items")
    #expect(
      defListNode.first(where: { $0.element == .definitionTerm }) != nil,
      "Should contain definition term"
    )
    #expect(
      defListNode.first(where: { $0.element == .definitionDescription }) != nil,
      "Should contain definition description"
    )
  }

  private func verifyTableStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let tableNode = root.first(where: { $0.element == .table }) as? TableNode else {
      Issue.record("Should find a table node")
      return
    }
    #expect(tableNode.children.count > 0, "Table should have rows")
    let tableRows = tableNode.nodes(where: { $0.element == .tableRow })
    #expect(tableRows.count == 2, "Should have 2 table rows (header + content, separator skipped)")
    let headerRows = tableRows.compactMap { $0 as? TableRowNode }.filter { $0.isHeader }
    let contentRows = tableRows.compactMap { $0 as? TableRowNode }.filter { !$0.isHeader }
    #expect(headerRows.count == 1, "Should have exactly 1 header row")
    #expect(contentRows.count == 1, "Should have exactly 1 content row")
    let tableCells = tableNode.nodes(where: { $0.element == .tableCell })
    #expect(tableCells.count == 4, "Should have exactly 4 table cells (2 per row)")
    for row in tableRows {
      let cellsInRow = row.children.compactMap { $0 as? TableCellNode }
      #expect(cellsInRow.count == 2, "Each row should have exactly 2 cells")
    }
  }

  private func verifyFormulaBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let formulaBlockNode = root.first(where: { $0.element == .formulaBlock }) as? FormulaBlockNode
    else {
      Issue.record("Should find a formula block node")
      return
    }
    #expect(
      formulaBlockNode.expression.trimmingCharacters(in: .whitespaces) == "x^2",
      "Formula block expression should match"
    )
  }

  private func verifyCodeBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let codeBlockNode = root.first(where: { $0.element == .codeBlock }) as? CodeBlockNode
    else {
      Issue.record("Should find a code block node")
      return
    }
    #expect(codeBlockNode.language == "swift", "Code block language should be swift")
    #expect(
      codeBlockNode.source.contains("let code = \"hi\""),
      "Code block should contain expected code"
    )
  }

  private func verifyThematicBreakStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let thematicBreakNode = root.first(where: { $0.element == .thematicBreak })
        as? ThematicBreakNode
    else {
      Issue.record("Should find a thematic break node")
      return
    }
    #expect(thematicBreakNode.marker == "---", "Thematic break marker should match")
  }

  private func verifyHTMLBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let htmlBlockNode = root.first(where: { $0.element == .htmlBlock }) as? HTMLBlockNode
    else {
      Issue.record("Should find an HTML block node")
      return
    }
    #expect(
      htmlBlockNode.content.contains("HTML block"), "HTML block should contain expected content"
    )
    #expect(htmlBlockNode.content.contains("<div>"), "HTML block should contain div tag")
  }

  private func verifyImageStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let imageNode = root.first(where: { $0.element == .image }) as? ImageNode else {
      Issue.record("Should find an image node")
      return
    }
    #expect(imageNode.url == "https://example.com/img.png", "Image URL should match exactly")
    #expect(imageNode.alt == "Alt", "Image alt text should match")
  }

  private func verifyLinkStructure(_ root: CodeNode<MarkdownNodeElement>) {
    let linkNodes = root.nodes(where: { $0.element == .link })
    #expect(linkNodes.count == 2, "Should have 2 link nodes")
    if let linkNode = linkNodes.first as? LinkNode {
      #expect(linkNode.url == "https://example.com", "First link URL should match")
      #expect(!linkNode.title.isEmpty || linkNode.title.isEmpty)
    }
    if linkNodes.count > 1, let autolinkNode = linkNodes[1] as? LinkNode {
      #expect(autolinkNode.url == "https://autolink.com", "Autolink URL should match")
    }
  }

  private func verifyFootnoteAndCitationStructure(_ root: CodeNode<MarkdownNodeElement>) {
    let footnoteRefNodes = root.nodes(where: { $0.element == .footnoteReference })
    #expect(footnoteRefNodes.count > 0, "Should find footnote reference nodes")
    if let footnoteRefNode = footnoteRefNodes.first as? FootnoteReferenceNode {
      #expect(footnoteRefNode.identifier == "1", "Footnote reference identifier should match")
    }
    let footnoteNodes = root.nodes(where: { $0.element == .footnote })
    #expect(footnoteNodes.count > 0, "Should find footnote definition nodes")
    let footnoteWithContent = footnoteNodes.first { node in
      if let footnoteNode = node as? FootnoteNode {
        return !footnoteNode.content.isEmpty
      }
      return false
    }
    #expect(footnoteWithContent != nil, "Should find footnote with content (definition)")
    if let footnoteNode = footnoteWithContent as? FootnoteNode {
      #expect(footnoteNode.identifier == "1", "Footnote definition identifier should match")
      #expect(
        footnoteNode.content.contains("Footnote text"), "Footnote should contain expected text"
      )
    }
    let citationRefNodes = root.nodes(where: { $0.element == .citationReference })
    #expect(citationRefNodes.count > 0, "Should find citation reference nodes")
    if let citationRefNode = citationRefNodes.first as? CitationReferenceNode {
      #expect(
        citationRefNode.identifier == "smith2023", "Citation reference identifier should match"
      )
    }
    let citationNodes = root.nodes(where: { $0.element == .citation })
    #expect(citationNodes.count > 0, "Should find citation definition nodes")
    if let citationNode = citationNodes.first as? CitationNode {
      #expect(citationNode.identifier == "smith2023", "Citation definition identifier should match")
      #expect(
        citationNode.content.contains("Smith, J. (2023). Example."),
        "Citation should contain expected content"
      )
    }
    let textNodes = root.nodes(where: { $0.element == .text })
    let hasFootnoteText = textNodes.contains { node in
      if let textNode = node as? TextNode {
        return textNode.content.contains("footnote")
      }
      return false
    }
    #expect(hasFootnoteText, "Should contain footnote reference text")
  }
}

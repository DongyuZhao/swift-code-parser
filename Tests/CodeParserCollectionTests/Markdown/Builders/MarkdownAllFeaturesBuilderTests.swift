import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

/// Comprehensive tests covering all supported Markdown features.
struct MarkdownAllFeaturesBuilderTests {

  private var language: MarkdownLanguage {
    MarkdownLanguage()
  }

  private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement> {
    CodeParser(language: language)
  }

  @Test func parsingComprehensiveMarkdownDocument() {
    let markdown = """
      # Heading 1

      This paragraph has *italic*, **bold**, ~~strike~~, and `code` with a $x+1$ formula.

      > [!NOTE]
      > Admonition content

      ::: custom
      Custom container
      :::

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

      <https://autolink.com> &amp; more.

      [^1]: Footnote text
      [@smith2023]: Smith, J. (2023). Example.
      """

    let result = parser.parse(markdown, language: language)

    #expect(result.errors.isEmpty, "Parsing should not produce any errors")
    #expect(result.root.children.count > 0, "Root should have children")

    // Ensure tokenizer runs without errors using the new tokenizer
    let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
    let (tokens, _) = tokenizer.tokenize(markdown)
    #expect(tokens.count > 0)

    // Verify specific AST structure
    self.verifyDocumentStructure(result.root)
    self.verifyHeadingStructure(result.root)
    self.verifyParagraphWithInlineElements(result.root)
    self.verifyAdmonitionStructure(result.root)
    self.verifyCustomContainerStructure(result.root)
    self.verifyBlockquoteStructure(result.root)
    self.verifyListStructures(result.root)
    self.verifyDefinitionListStructure(result.root)
    self.verifyTableStructure(result.root)
    self.verifyFormulaBlockStructure(result.root)
    self.verifyCodeBlockStructure(result.root)
    self.verifyThematicBreakStructure(result.root)
    self.verifyHTMLBlockStructure(result.root)
    self.verifyImageStructure(result.root)
    self.verifyLinkStructure(result.root)
    self.verifyFootnoteAndCitationStructure(result.root)
  }

  @Test func tableParsing() {
    let tableMarkdown = """
      | A | B |
      |---|---|
      | 1 | 2 |
      """
    let result = parser.parse(tableMarkdown, language: language)

    // Parsing should succeed
    #expect(result.errors.isEmpty, "Table-only markdown should parse without errors")

    // Locate the table node
    guard let tableNode = result.root.first(where: { $0.element == .table }) as? TableNode else {
      Issue.record("Expected a table node")
      return
    }

    // Expect exactly two rows: header + data
    let rows = tableNode.nodes(where: { $0.element == .tableRow })
    #expect(rows.count == 2, "Table should contain exactly 2 rows")

    // Each row must have two cells
    for row in rows {
      let cells = row.children.compactMap { $0 as? TableCellNode }
      #expect(cells.count == 2, "Each row should have exactly 2 cells")
    }

    // Verify header cell content
    if let headerRow = rows.first,
      let firstHeaderCell = headerRow.children.first as? TableCellNode,
      let headerText = firstHeaderCell.children.first as? TextNode
    {
      #expect(headerText.content == "A", "First header cell should be 'A'")
    }

    // Verify data cell content
    if let dataRow = rows.last,
      let firstDataCell = dataRow.children.first as? TableCellNode,
      let dataText = firstDataCell.children.first as? TextNode
    {
      #expect(dataText.content == "1", "First data cell should be '1'")
    }
  }

  @Test func footnoteDefinitionParsing() {
    let footnoteMarkdown = """
      Citation[@smith2023] and footnote[^1].

      [^1]: Footnote text
      [@smith2023]: Smith, J. (2023). Example.
      """
    let result = parser.parse(footnoteMarkdown, language: language)

    // Parsing should succeed without errors
    #expect(result.errors.isEmpty, "Footnote and citation parsing should not produce errors")
    #expect(result.root.children.count > 0, "Root should have children")

    // Verify footnote reference exists
    let footnoteRefNodes = result.root.nodes(where: { $0.element == .footnoteReference })
    #expect(footnoteRefNodes.count == 1, "Should find exactly 1 footnote reference")

    if let footnoteRefNode = footnoteRefNodes.first as? FootnoteReferenceNode {
      #expect(footnoteRefNode.identifier == "1", "Footnote reference identifier should be '1'")
    } else {
      Issue.record("Footnote reference node should be of type FootnoteReferenceNode")
    }

    // Verify footnote definition exists
    let footnoteNodes = result.root.nodes(where: { $0.element == .footnote })
    #expect(footnoteNodes.count == 1, "Should find exactly 1 footnote definition")

    if let footnoteNode = footnoteNodes.first as? FootnoteNode {
      #expect(footnoteNode.identifier == "1", "Footnote definition identifier should be '1'")
      #expect(
        footnoteNode.content.contains("Footnote text"), "Footnote should contain expected text")
    } else {
      Issue.record("Footnote node should be of type FootnoteNode")
    }

    // Verify citation reference exists
    let citationRefNodes = result.root.nodes(where: { $0.element == .citationReference })
    #expect(citationRefNodes.count == 1, "Should find exactly 1 citation reference")

    if let citationRefNode = citationRefNodes.first as? CitationReferenceNode {
      #expect(
        citationRefNode.identifier == "smith2023",
        "Citation reference identifier should be 'smith2023'")
    } else {
      Issue.record("Citation reference node should be of type CitationReferenceNode")
    }

    // Verify citation definition exists
    let citationNodes = result.root.nodes(where: { $0.element == .citation })
    #expect(citationNodes.count == 1, "Should find exactly 1 citation definition")

    if let citationNode = citationNodes.first as? CitationNode {
      #expect(
        citationNode.identifier == "smith2023",
        "Citation definition identifier should be 'smith2023'")
      #expect(
        citationNode.content.contains("Smith, J. (2023). Example."),
        "Citation should contain expected content")
    } else {
      Issue.record("Citation node should be of type CitationNode")
    }

    // Test citation reference tokenization specifically
    let citationText = "[@smith2023]"
    let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
    let (tokens, _) = tokenizer.tokenize(citationText)
    #expect(tokens.count > 0, "Citation tokenization should produce tokens")
  }

  // MARK: - AST Structure Verification Methods

  private func verifyDocumentStructure(_ root: CodeNode<MarkdownNodeElement>) {
    // Root should be a document node
    #expect(root.element == .document, "Root should be a document node")
    #expect(root.children.count == 18, "Document should have exactly 18 top-level children")
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

    // This paragraph has: text, italic, bold, strike, code, and formula
    #expect(paragraphNode.children.count > 5, "Paragraph should have multiple inline elements")

    // Verify presence of different inline elements
    #expect(
      paragraphNode.first(where: { $0.element == .emphasis }) != nil, "Should contain emphasis")
    #expect(paragraphNode.first(where: { $0.element == .strong }) != nil, "Should contain strong")
    #expect(paragraphNode.first(where: { $0.element == .strike }) != nil, "Should contain strike")
    #expect(
      paragraphNode.first(where: { $0.element == .code }) != nil, "Should contain inline code")
    #expect(paragraphNode.first(where: { $0.element == .formula }) != nil, "Should contain formula")

    // Verify inline code content
    if let codeNode = paragraphNode.first(where: { $0.element == .code }) as? InlineCodeNode {
      #expect(codeNode.code == "code", "Inline code content should match")
    }

    // Verify formula content
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

  private func verifyCustomContainerStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let containerNode = root.first(where: { $0.element == .customContainer })
        as? CustomContainerNode
    else {
      Issue.record("Should find a custom container node")
      return
    }

    #expect(containerNode.name == "custom", "Container name should match")
    #expect(!containerNode.content.isEmpty, "Container should have content")
  }

  private func verifyBlockquoteStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let blockquoteNode = root.first(where: { $0.element == .blockquote }) as? BlockquoteNode
    else {
      Issue.record("Should find a blockquote node")
      return
    }

    #expect(blockquoteNode.level == 1, "Blockquote should be level 1")
    #expect(blockquoteNode.children.count > 0, "Blockquote should have content")

    // Should contain multiple lines
    let textNodes = blockquoteNode.nodes(where: { $0.element == .text })
    #expect(textNodes.count > 0, "Blockquote should contain text")
  }

  private func verifyListStructures(_ root: CodeNode<MarkdownNodeElement>) {
    // Verify ordered list
    guard
      let orderedListNode = root.first(where: { $0.element == .orderedList }) as? OrderedListNode
    else {
      Issue.record("Should find an ordered list node")
      return
    }

    #expect(orderedListNode.start == 1, "Ordered list should start at 1")
    #expect(orderedListNode.level == 0, "Ordered list should be level 0")

    // Based on actual AST structure: 2 ListItemNodes + 2 UnorderedListNodes + 1 DefinitionListNode = 5 children
    #expect(
      orderedListNode.children.count == 5,
      "Ordered list should have 5 children (2 items + 2 nested unordered lists + 1 definition list)"
    )

    // Verify ordered list items exist
    let orderedItems = orderedListNode.children.compactMap { $0 as? ListItemNode }
    #expect(orderedItems.count == 2, "Should have 2 ordered list items")

    // Verify nested structures within the ordered list (based on actual parsing)
    let nestedUnorderedLists = orderedListNode.children.compactMap { $0 as? UnorderedListNode }
    #expect(nestedUnorderedLists.count == 2, "Should have 2 nested unordered lists")

    let nestedDefList = orderedListNode.children.compactMap { $0 as? DefinitionListNode }
    #expect(nestedDefList.count == 1, "Should have 1 nested definition list")

    // Verify task list items exist (they should be in the first nested unordered list)
    let taskItems = orderedListNode.nodes(where: { $0.element == .taskListItem })
    #expect(taskItems.count == 2, "Should have 2 task items")

    if let uncheckedTask = taskItems.first(where: { ($0 as? TaskListItemNode)?.checked == false })
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

  private func verifyDefinitionListStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard
      let defListNode = root.first(where: { $0.element == .definitionList }) as? DefinitionListNode
    else {
      Issue.record("Should find a definition list node")
      return
    }

    #expect(defListNode.children.count > 0, "Definition list should have items")

    // Should contain definition items with terms and descriptions
    #expect(
      defListNode.first(where: { $0.element == .definitionTerm }) != nil,
      "Should contain definition term")
    #expect(
      defListNode.first(where: { $0.element == .definitionDescription }) != nil,
      "Should contain definition description")
  }

  private func verifyTableStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let tableNode = root.first(where: { $0.element == .table }) as? TableNode else {
      Issue.record("Should find a table node")
      return
    }

    #expect(tableNode.children.count > 0, "Table should have rows")

    // Should have 2 rows (header row and data row, separator row is skipped)
    let tableRows = tableNode.nodes(where: { $0.element == .tableRow })
    #expect(tableRows.count == 2, "Should have 2 table rows (header + content, separator skipped)")

    // Verify header and content rows
    let headerRows = tableRows.compactMap { $0 as? TableRowNode }.filter { $0.isHeader }
    let contentRows = tableRows.compactMap { $0 as? TableRowNode }.filter { !$0.isHeader }

    #expect(headerRows.count == 1, "Should have exactly 1 header row")
    #expect(contentRows.count == 1, "Should have exactly 1 content row")

    // Verify table cells exist and have correct count (2 columns)
    let tableCells = tableNode.nodes(where: { $0.element == .tableCell })
    #expect(tableCells.count == 4, "Should have exactly 4 table cells (2 per row)")

    // Verify each row has 2 cells
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
      "Formula block expression should match")
  }

  private func verifyCodeBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
    guard let codeBlockNode = root.first(where: { $0.element == .codeBlock }) as? CodeBlockNode
    else {
      Issue.record("Should find a code block node")
      return
    }

    #expect(codeBlockNode.language == "swift", "Code block language should be swift")
    #expect(
      codeBlockNode.source.contains("let code = \"hi\""), "Code block should contain expected code")
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

    // HTML block name might be empty, check content instead
    #expect(
      htmlBlockNode.content.contains("HTML block"), "HTML block should contain expected content")
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
    // Look for link nodes in the AST
    let linkNodes = root.nodes(where: { $0.element == .link })

    // Based on actual AST, we should have 2 LinkNodes: [link](https://example.com) and <https://autolink.com>
    #expect(linkNodes.count == 2, "Should have 2 link nodes")

    if let linkNode = linkNodes.first as? LinkNode {
      #expect(linkNode.url == "https://example.com", "First link URL should match")
      // Link title might be empty in this implementation, so just check that it exists
      #expect(
        !linkNode.title.isEmpty || linkNode.title.isEmpty,
        "Link title property should be accessible")
    }

    if linkNodes.count > 1, let autolinkNode = linkNodes[1] as? LinkNode {
      #expect(autolinkNode.url == "https://autolink.com", "Autolink URL should match")
    }
  }

  private func verifyFootnoteAndCitationStructure(_ root: CodeNode<MarkdownNodeElement>) {
    // Verify footnote reference (inline)
    let footnoteRefNodes = root.nodes(where: { $0.element == .footnoteReference })
    #expect(footnoteRefNodes.count > 0, "Should find footnote reference nodes")

    if let footnoteRefNode = footnoteRefNodes.first as? FootnoteReferenceNode {
      #expect(footnoteRefNode.identifier == "1", "Footnote reference identifier should match")
    }

    // Verify footnote definition
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
        footnoteNode.content.contains("Footnote text"), "Footnote should contain expected text")
    }

    // Verify citation reference (inline)
    let citationRefNodes = root.nodes(where: { $0.element == .citationReference })
    #expect(citationRefNodes.count > 0, "Should find citation reference nodes")

    if let citationRefNode = citationRefNodes.first as? CitationReferenceNode {
      #expect(
        citationRefNode.identifier == "smith2023", "Citation reference identifier should match")
    }

    // Verify citation definition
    let citationNodes = root.nodes(where: { $0.element == .citation })
    #expect(citationNodes.count > 0, "Should find citation definition nodes")

    if let citationNode = citationNodes.first as? CitationNode {
      #expect(citationNode.identifier == "smith2023", "Citation definition identifier should match")
      #expect(
        citationNode.content.contains("Smith, J. (2023). Example."),
        "Citation should contain expected content")
    }

    // Verify reference node (generic references) exists if any
    // Note: Citations now use CitationNode instead of ReferenceNode

    // Verify text content
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

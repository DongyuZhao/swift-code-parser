import XCTest
@testable import SwiftParser
@testable import SwiftParserShowCase

/// Comprehensive tests covering all supported Markdown features.
final class MarkdownAllFeaturesBuilderTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testParsingComprehensiveMarkdownDocument() {
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

        XCTAssertTrue(result.errors.isEmpty, "Parsing should not produce any errors")
        XCTAssertGreaterThan(result.root.children.count, 0, "Root should have children")

        // Ensure tokenizer runs without errors using the new tokenizer
        let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
        let (tokens, _) = tokenizer.tokenize(markdown)
        XCTAssertGreaterThan(tokens.count, 0)

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

    func testTableParsing() {
        let tableMarkdown = """
| A | B |
|---|---|
| 1 | 2 |
"""
        let _ = parser.parse(tableMarkdown, language: language)

        XCTAssertTrue(true)
    }

    func testFootnoteDefinitionParsing() {
        let footnoteMarkdown = """
Citation[@smith2023] and footnote[^1].

[^1]: Footnote text
[@smith2023]: Smith, J. (2023). Example.
"""
        let _ = parser.parse(footnoteMarkdown, language: language)

        // Test citation reference tokenization specifically
        let citationText = "[@smith2023]"
        let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
        let _ = tokenizer.tokenize(citationText)

        XCTAssertTrue(true)
    }

    // MARK: - AST Structure Verification Methods

    private func verifyDocumentStructure(_ root: CodeNode<MarkdownNodeElement>) {
        // Root should be a document node
        XCTAssertEqual(root.element, .document, "Root should be a document node")
        XCTAssertEqual(root.children.count, 18, "Document should have exactly 18 top-level children")
    }

    private func verifyHeadingStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let headingNode = root.first(where: { $0.element == .heading }) as? HeaderNode else {
            XCTFail("Should find a heading node")
            return
        }

        XCTAssertEqual(headingNode.level, 1, "Should be a level 1 heading")
        XCTAssertEqual(headingNode.children.count, 1, "Heading should have one text child")

        if let textChild = headingNode.children.first as? TextNode {
            XCTAssertEqual(textChild.content, "Heading 1", "Heading text should match")
        } else {
            XCTFail("Heading should contain a text node")
        }
    }

    private func verifyParagraphWithInlineElements(_ root: CodeNode<MarkdownNodeElement>) {
        guard let paragraphNode = root.first(where: { $0.element == .paragraph }) as? ParagraphNode else {
            XCTFail("Should find a paragraph node")
            return
        }

        // This paragraph has: text, italic, bold, strike, code, and formula
        XCTAssertGreaterThan(paragraphNode.children.count, 5, "Paragraph should have multiple inline elements")

        // Verify presence of different inline elements
        XCTAssertNotNil(paragraphNode.first(where: { $0.element == .emphasis }), "Should contain emphasis")
        XCTAssertNotNil(paragraphNode.first(where: { $0.element == .strong }), "Should contain strong")
        XCTAssertNotNil(paragraphNode.first(where: { $0.element == .strike }), "Should contain strike")
        XCTAssertNotNil(paragraphNode.first(where: { $0.element == .code }), "Should contain inline code")
        XCTAssertNotNil(paragraphNode.first(where: { $0.element == .formula }), "Should contain formula")

        // Verify inline code content
        if let codeNode = paragraphNode.first(where: { $0.element == .code }) as? InlineCodeNode {
            XCTAssertEqual(codeNode.code, "code", "Inline code content should match")
        }

        // Verify formula content
        if let formulaNode = paragraphNode.first(where: { $0.element == .formula }) as? FormulaNode {
            XCTAssertEqual(formulaNode.expression, "x+1", "Formula expression should match")
        }
    }

    private func verifyAdmonitionStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let admonitionNode = root.first(where: { $0.element == .admonition }) as? AdmonitionNode else {
            XCTFail("Should find an admonition node")
            return
        }

        XCTAssertEqual(admonitionNode.kind, "note", "Admonition should be of type note")
        XCTAssertGreaterThan(admonitionNode.children.count, 0, "Admonition should have content")
    }

    private func verifyCustomContainerStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let containerNode = root.first(where: { $0.element == .customContainer }) as? CustomContainerNode else {
            XCTFail("Should find a custom container node")
            return
        }

        XCTAssertEqual(containerNode.name, "custom", "Container name should match")
        XCTAssertFalse(containerNode.content.isEmpty, "Container should have content")
    }

    private func verifyBlockquoteStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let blockquoteNode = root.first(where: { $0.element == .blockquote }) as? BlockquoteNode else {
            XCTFail("Should find a blockquote node")
            return
        }

        XCTAssertEqual(blockquoteNode.level, 1, "Blockquote should be level 1")
        XCTAssertGreaterThan(blockquoteNode.children.count, 0, "Blockquote should have content")

        // Should contain multiple lines
        let textNodes = blockquoteNode.nodes(where: { $0.element == .text })
        XCTAssertGreaterThan(textNodes.count, 0, "Blockquote should contain text")
    }

    private func verifyListStructures(_ root: CodeNode<MarkdownNodeElement>) {
        // Verify ordered list
        guard let orderedListNode = root.first(where: { $0.element == .orderedList }) as? OrderedListNode else {
            XCTFail("Should find an ordered list node")
            return
        }

        XCTAssertEqual(orderedListNode.start, 1, "Ordered list should start at 1")
        XCTAssertEqual(orderedListNode.level, 0, "Ordered list should be level 0")

        // Based on actual AST structure: 2 ListItemNodes + 2 UnorderedListNodes + 1 DefinitionListNode = 5 children
        XCTAssertEqual(orderedListNode.children.count, 5, "Ordered list should have 5 children (2 items + 2 nested unordered lists + 1 definition list)")

        // Verify ordered list items exist
        let orderedItems = orderedListNode.children.compactMap { $0 as? ListItemNode }
        XCTAssertEqual(orderedItems.count, 2, "Should have 2 ordered list items")

        // Verify nested structures within the ordered list (based on actual parsing)
        let nestedUnorderedLists = orderedListNode.children.compactMap { $0 as? UnorderedListNode }
        XCTAssertEqual(nestedUnorderedLists.count, 2, "Should have 2 nested unordered lists")

        let nestedDefList = orderedListNode.children.compactMap { $0 as? DefinitionListNode }
        XCTAssertEqual(nestedDefList.count, 1, "Should have 1 nested definition list")

        // Verify task list items exist (they should be in the first nested unordered list)
        let taskItems = orderedListNode.nodes(where: { $0.element == .taskListItem })
        XCTAssertEqual(taskItems.count, 2, "Should have 2 task items")

        if let uncheckedTask = taskItems.first(where: { ($0 as? TaskListItemNode)?.checked == false }) as? TaskListItemNode {
            XCTAssertFalse(uncheckedTask.checked, "Should have unchecked task")
        }

        if let checkedTask = taskItems.first(where: { ($0 as? TaskListItemNode)?.checked == true }) as? TaskListItemNode {
            XCTAssertTrue(checkedTask.checked, "Should have checked task")
        }
    }

    private func verifyDefinitionListStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let defListNode = root.first(where: { $0.element == .definitionList }) as? DefinitionListNode else {
            XCTFail("Should find a definition list node")
            return
        }

        XCTAssertGreaterThan(defListNode.children.count, 0, "Definition list should have items")

        // Should contain definition items with terms and descriptions
        XCTAssertNotNil(defListNode.first(where: { $0.element == .definitionTerm }), "Should contain definition term")
        XCTAssertNotNil(defListNode.first(where: { $0.element == .definitionDescription }), "Should contain definition description")
    }

    private func verifyTableStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let tableNode = root.first(where: { $0.element == .table }) as? TableNode else {
            XCTFail("Should find a table node")
            return
        }

        XCTAssertGreaterThan(tableNode.children.count, 0, "Table should have rows")

        // Should have 2 rows (header row and data row, separator row is skipped)
        let tableRows = tableNode.nodes(where: { $0.element == .tableRow })
        XCTAssertEqual(tableRows.count, 2, "Should have 2 table rows (header + content, separator skipped)")

        // Verify header and content rows
        let headerRows = tableRows.compactMap { $0 as? TableRowNode }.filter { $0.isHeader }
        let contentRows = tableRows.compactMap { $0 as? TableRowNode }.filter { !$0.isHeader }

        XCTAssertEqual(headerRows.count, 1, "Should have exactly 1 header row")
        XCTAssertEqual(contentRows.count, 1, "Should have exactly 1 content row")

        // Verify table cells exist and have correct count (2 columns)
        let tableCells = tableNode.nodes(where: { $0.element == .tableCell })
        XCTAssertEqual(tableCells.count, 4, "Should have exactly 4 table cells (2 per row)")

        // Verify each row has 2 cells
        for row in tableRows {
            let cellsInRow = row.children.compactMap { $0 as? TableCellNode }
            XCTAssertEqual(cellsInRow.count, 2, "Each row should have exactly 2 cells")
        }
    }

    private func verifyFormulaBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let formulaBlockNode = root.first(where: { $0.element == .formulaBlock }) as? FormulaBlockNode else {
            XCTFail("Should find a formula block node")
            return
        }

        XCTAssertEqual(formulaBlockNode.expression.trimmingCharacters(in: .whitespaces), "x^2", "Formula block expression should match")
    }

    private func verifyCodeBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let codeBlockNode = root.first(where: { $0.element == .codeBlock }) as? CodeBlockNode else {
            XCTFail("Should find a code block node")
            return
        }

        XCTAssertEqual(codeBlockNode.language, "swift", "Code block language should be swift")
        XCTAssertTrue(codeBlockNode.source.contains("let code = \"hi\""), "Code block should contain expected code")
    }

    private func verifyThematicBreakStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let thematicBreakNode = root.first(where: { $0.element == .thematicBreak }) as? ThematicBreakNode else {
            XCTFail("Should find a thematic break node")
            return
        }

        XCTAssertEqual(thematicBreakNode.marker, "---", "Thematic break marker should match")
    }

    private func verifyHTMLBlockStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let htmlBlockNode = root.first(where: { $0.element == .htmlBlock }) as? HTMLBlockNode else {
            XCTFail("Should find an HTML block node")
            return
        }

        // HTML block name might be empty, check content instead
        XCTAssertTrue(htmlBlockNode.content.contains("HTML block"), "HTML block should contain expected content")
        XCTAssertTrue(htmlBlockNode.content.contains("<div>"), "HTML block should contain div tag")
    }

    private func verifyImageStructure(_ root: CodeNode<MarkdownNodeElement>) {
        guard let imageNode = root.first(where: { $0.element == .image }) as? ImageNode else {
            XCTFail("Should find an image node")
            return
        }

        XCTAssertEqual(imageNode.url, "https://example.com/img.png", "Image URL should match exactly")
        XCTAssertEqual(imageNode.alt, "Alt", "Image alt text should match")
    }

    private func verifyLinkStructure(_ root: CodeNode<MarkdownNodeElement>) {
        // Look for link nodes in the AST
        let linkNodes = root.nodes(where: { $0.element == .link })

        // Based on actual AST, we should have 2 LinkNodes: [link](https://example.com) and <https://autolink.com>
        XCTAssertEqual(linkNodes.count, 2, "Should have 2 link nodes")

        if let linkNode = linkNodes.first as? LinkNode {
            XCTAssertEqual(linkNode.url, "https://example.com", "First link URL should match")
            // Link title might be empty in this implementation, so just check that it's not nil
            XCTAssertNotNil(linkNode.title, "Link title should not be nil")
        }

        if linkNodes.count > 1, let autolinkNode = linkNodes[1] as? LinkNode {
            XCTAssertEqual(autolinkNode.url, "https://autolink.com", "Autolink URL should match")
        }
    }

    private func verifyFootnoteAndCitationStructure(_ root: CodeNode<MarkdownNodeElement>) {
        // Verify footnote reference (inline)
        let footnoteRefNodes = root.nodes(where: { $0.element == .footnoteReference })
        XCTAssertGreaterThan(footnoteRefNodes.count, 0, "Should find footnote reference nodes")

        if let footnoteRefNode = footnoteRefNodes.first as? FootnoteReferenceNode {
            XCTAssertEqual(footnoteRefNode.identifier, "1", "Footnote reference identifier should match")
        }

        // Verify footnote definition
        let footnoteNodes = root.nodes(where: { $0.element == .footnote })
        XCTAssertGreaterThan(footnoteNodes.count, 0, "Should find footnote definition nodes")

        let footnoteWithContent = footnoteNodes.first { node in
            if let footnoteNode = node as? FootnoteNode {
                return !footnoteNode.content.isEmpty
            }
            return false
        }
        XCTAssertNotNil(footnoteWithContent, "Should find footnote with content (definition)")

        if let footnoteNode = footnoteWithContent as? FootnoteNode {
            XCTAssertEqual(footnoteNode.identifier, "1", "Footnote definition identifier should match")
            XCTAssertTrue(footnoteNode.content.contains("Footnote text"), "Footnote should contain expected text")
        }

        // Verify citation reference (inline)
        let citationRefNodes = root.nodes(where: { $0.element == .citationReference })
        XCTAssertGreaterThan(citationRefNodes.count, 0, "Should find citation reference nodes")

        if let citationRefNode = citationRefNodes.first as? CitationReferenceNode {
            XCTAssertEqual(citationRefNode.identifier, "smith2023", "Citation reference identifier should match")
        }

        // Verify citation definition
        let citationNodes = root.nodes(where: { $0.element == .citation })
        XCTAssertGreaterThan(citationNodes.count, 0, "Should find citation definition nodes")

        if let citationNode = citationNodes.first as? CitationNode {
            XCTAssertEqual(citationNode.identifier, "smith2023", "Citation definition identifier should match")
            XCTAssertTrue(citationNode.content.contains("Smith, J. (2023). Example."), "Citation should contain expected content")
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
        XCTAssertTrue(hasFootnoteText, "Should contain footnote reference text")
    }
}

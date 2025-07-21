import XCTest
@testable import SwiftParser

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

::: note
Admonition content
:::

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

        let root = language.root(of: markdown)
        let (node, context) = parser.parse(markdown, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertGreaterThan(node.children.count, 0)

        // Ensure tokenizer runs without errors
        let tokens = MarkdownTokenizer().tokenize(markdown)
        XCTAssertGreaterThan(tokens.count, 0)

        // Verify important structures exist
        XCTAssertNotNil(node.first { ($0 as? HeaderNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? ParagraphNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? BlockquoteNode) != nil })
        XCTAssertEqual(node.nodes { $0.element == .orderedList }.count, 1)
        XCTAssertEqual(node.nodes { $0.element == .unorderedList }.count, 2)
        XCTAssertNotNil(node.first { ($0 as? DefinitionListNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? TableNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? FormulaBlockNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? CodeBlockNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? ThematicBreakNode) != nil })
        XCTAssertEqual(node.nodes { $0.element == .footnote }.count, 1)
        XCTAssertNotNil(node.first { ($0 as? HTMLBlockNode) != nil })
        XCTAssertNotNil(node.first { ($0 as? ImageNode) != nil })
    }
}


import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownTokenizerComplexTests: XCTestCase {

    private var tokenizer: CodeTokenizer<MarkdownTokenElement>!

    override func setUp() {
        super.setUp()
        let language = MarkdownLanguage()
        tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
    }

    override func tearDown() {
        tokenizer = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Helper to assert token properties
    private func assertToken(
        at index: Int,
        in tokens: [any CodeToken<MarkdownTokenElement>],
        expectedElement: MarkdownTokenElement,
        expectedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard index < tokens.count else {
            XCTFail("Index \(index) out of bounds for tokens array with count \(tokens.count)", file: file, line: line)
            return
        }

        let token = tokens[index]
        XCTAssertEqual(token.element, expectedElement, "Token element mismatch at index \(index)", file: file, line: line)
        XCTAssertEqual(token.text, expectedText, "Token text mismatch at index \(index)", file: file, line: line)
    }

    /// Helper to get token elements as array
    private func getTokenElements(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownTokenElement] {
        return tokens.map { $0.element }
    }

    // MARK: - Complex Tests

    func testComplexMarkdownStructures() {
        let testCases: [(String, [MarkdownTokenElement], String)] = [
            (
                "# Heading with **bold** and *italic*",
                [.hash, .space, .text, .space, .text, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .space, .asterisk, .text, .asterisk, .eof],
                "Heading with mixed formatting"
            ),
            (
                "Text with `inline code` and **bold** text",
                [.text, .space, .text, .space, .inlineCode, .space, .text, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .eof],
                "Mixed inline elements"
            ),
            (
                "Link with [text](url) and ![image](src)",
                [.text, .space, .text, .space, .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .space, .text, .space, .exclamation, .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof],
                "Links and images"
            ),
            (
                "List with - **bold** item and - *italic* item",
                [.text, .space, .text, .space, .dash, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .space, .text, .space, .dash, .space, .asterisk, .text, .asterisk, .space, .text, .eof],
                "Lists with formatting"
            ),
            (
                "Quote with > **bold** text and > *italic* text",
                [.text, .space, .text, .space, .gt, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .space, .text, .space, .gt, .space, .asterisk, .text, .asterisk, .space, .text, .eof],
                "Quotes with formatting"
            ),
            (
                "Math with $x = 1$ and code with `y = 2`",
                [.text, .space, .text, .space, .formula, .space, .text, .space, .text, .space, .text, .space, .inlineCode, .eof],
                "Math and code"
            ),
            (
                "HTML with <strong>bold</strong> and markdown **bold**",
                [.text, .space, .text, .space, .htmlBlock, .space, .text, .space, .text, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .eof],
                "HTML and markdown"
            )
        ]

        for (input, expectedElements, description) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let actual = getTokenElements(tokens)
            XCTAssertEqual(actual, expectedElements, "Token sequence mismatch for: \(description)")
        }
    }

    func testMixedComplexSyntax() {
        let testCases: [(String, [MarkdownTokenElement], String)] = [
            (
                "**Bold with `code` inside**",
                [.asterisk, .asterisk, .text, .space, .text, .space, .inlineCode, .space, .text, .asterisk, .asterisk, .eof],
                "Bold with code"
            ),
            (
                "*Italic with **bold** inside*",
                [.asterisk, .text, .space, .text, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .asterisk, .eof],
                "Italic with bold"
            ),
            (
                "`Code with **bold** inside`",
                [.inlineCode, .eof],
                "Code with bold"
            ),
            (
                "$Math with text inside$",
                [.formula, .eof],
                "Math with text"
            ),
            (
                "<strong>HTML with `code` inside</strong>",
                [.htmlBlock, .eof],
                "HTML with code"
            ),
            (
                "<!-- Comment with **bold** inside -->",
                [.htmlComment, .eof],
                "Comment with bold"
            ),
            (
                "&amp; Entity with **bold** after",
                [.htmlEntity, .space, .text, .space, .text, .space, .asterisk, .asterisk, .text, .asterisk, .asterisk, .space, .text, .eof],
                "Entity with bold"
            ),
            (
                "# Heading with $math$ and [link](url)",
                [.hash, .space, .text, .space, .text, .space, .formula, .space, .text, .space, .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof],
                "Heading with math and link"
            )
        ]

        for (input, expectedElements, description) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let actual = getTokenElements(tokens)
            XCTAssertEqual(actual, expectedElements, "Token sequence mismatch for: \(description)")
        }
    }

    func testComplexDocumentStructure() {
        let complexDocument = """
        # Main Heading

        This is a paragraph with **bold** and *italic* text, plus some `inline code`.

        ## Subheading with Math

        Here's an inline formula: $E = mc^2$ and a display formula:

        $$\\int e^{-x^2} dx$$

        ### Lists and Tables

        - First item with [link](https://example.com)
        - Second item with ![image](image.jpg)
        - Third item with <strong>HTML</strong>

        | Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        | $x = 1$  | **Bold** | `code`   |
        | $y = 2$  | *Italic* | <em>HTML</em> |

        ### Blockquote

        > This is a quote with **bold** text and $math$ formula.
        >
        > > Nested quote with *italic* text.

        ### HTML and Math Combined

        Text with <strong>HTML bold</strong> and $math$ formula and $$display$$ math.

        <!-- This is an HTML comment -->

        &amp; HTML entity &lt;test&gt;
        """

        let (tokens, _) = tokenizer.tokenize(complexDocument)

        XCTAssertGreaterThan(tokens.count, 100, "Should produce many tokens for complex document")
        XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF")

        // Check that we have various token types
        let elements = getTokenElements(tokens)

        // Basic tokens
        XCTAssertTrue(elements.contains(.hash), "Should contain hash tokens")
        XCTAssertTrue(elements.contains(.asterisk), "Should contain asterisk tokens")
        XCTAssertTrue(elements.contains(.dash), "Should contain dash tokens")
        XCTAssertTrue(elements.contains(.pipe), "Should contain pipe tokens")
        XCTAssertTrue(elements.contains(.gt), "Should contain gt tokens")
        XCTAssertTrue(elements.contains(.leftBracket), "Should contain left bracket tokens")
        XCTAssertTrue(elements.contains(.rightBracket), "Should contain right bracket tokens")
        XCTAssertTrue(elements.contains(.leftParen), "Should contain left paren tokens")
        XCTAssertTrue(elements.contains(.rightParen), "Should contain right paren tokens")

        // Code tokens (now as complete tokens)
        XCTAssertTrue(elements.contains(.inlineCode), "Should contain inline code tokens")

        // HTML tokens
        XCTAssertTrue(elements.contains(.htmlBlock), "Should contain HTML block tokens")
        XCTAssertTrue(elements.contains(.htmlComment), "Should contain HTML comment tokens")
        XCTAssertTrue(elements.contains(.htmlEntity), "Should contain HTML entity tokens")

        // Math tokens
        XCTAssertTrue(elements.contains(.formula), "Should contain formula tokens")
        XCTAssertTrue(elements.contains(.formulaBlock), "Should contain formula block tokens")
    }

    func testPerformanceWithLargeDocument() {
        // Create a reasonably large document
        let largeText = Array(repeating: "This is a paragraph with **bold** and *italic* text. ", count: 50).joined()

        let (tokens, _) = tokenizer.tokenize(largeText)

        XCTAssertGreaterThan(tokens.count, 50, "Should produce many tokens for large document")
        XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF")
    }

    func testComplexCodeBlockScenarios() {
        let testCases: [(String, String, [MarkdownTokenElement])] = [
            // Fenced code blocks
            ("```swift\nlet x = 42\n```", "Simple fenced code block", [.fencedCodeBlock, .eof]),
            ("```\ncode without language\n```", "Fenced code block without language", [.fencedCodeBlock, .eof]),
            ("```python\nprint('hello')\n# comment\n```", "Fenced code block with comments", [.fencedCodeBlock, .eof]),

            // Indented code blocks
            ("    let x = 42\n    print(x)", "Simple indented code block", [.indentedCodeBlock, .eof]),
            ("\tcode with tab indent", "Tab indented code block", [.indentedCodeBlock, .eof]),

            // Mixed content
            ("Some text\n```swift\ncode\n```\nMore text", "Text with fenced code block", [.text, .space, .text, .newline, .fencedCodeBlock, .newline, .text, .space, .text, .eof]),

            // Unclosed code blocks
            ("```swift\nunclosed code block", "Unclosed fenced code block", [.fencedCodeBlock, .eof]),

            // Inline code
            ("This is `inline code` in text", "Inline code in text", [.text, .space, .text, .space, .inlineCode, .space, .text, .space, .text, .eof]),
            ("Multiple `code1` and `code2` inline", "Multiple inline code blocks", [.text, .space, .inlineCode, .space, .text, .space, .inlineCode, .space, .text, .eof]),
        ]

        for (input, description, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let actualElements = getTokenElements(tokens)

            XCTAssertEqual(actualElements.count, expectedElements.count,
                          "Token count mismatch for \(description): expected \(expectedElements.count), got \(actualElements.count)")

            for (index, expectedElement) in expectedElements.enumerated() {
                if index < actualElements.count {
                    XCTAssertEqual(actualElements[index], expectedElement,
                                  "Token \(index) mismatch for \(description): expected \(expectedElement), got \(actualElements[index])")
                }
            }
        }
    }

    func testUnclosedCodeBlockEdgeCases() {
        let testCases: [(String, String)] = [
            ("```\ncode without closing fence", "Basic unclosed fenced code block"),
            ("```swift\nlet x = 42\nprint(x)\n// no closing", "Unclosed Swift code block"),
            ("```\n\n\n  spaces and newlines", "Unclosed with spaces and newlines"),
            ("`unclosed inline code", "Unclosed inline code should not be treated as code"),
        ]

        for (input, description) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)

            if input.starts(with: "```") {
                // Should be treated as fenced code block
                XCTAssertEqual(tokens.first?.element, .fencedCodeBlock,
                              "Should be fenced code block for: \(description)")
                XCTAssertEqual(tokens.first?.text, input,
                              "Should contain full input for: \(description)")
            } else if input.starts(with: "`") && input.dropFirst().contains("`") == false {
                // Unclosed inline code should fall back to backtick
                XCTAssertEqual(tokens.first?.element, .text,
                              "Should be backtick for unclosed inline code: \(description)")
            }
        }
    }
}

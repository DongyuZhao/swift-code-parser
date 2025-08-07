import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownTokenBuilderTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testHeadingBuilderAppendsHeaderNodeWithText() {
        let input = "# Hello"
        let result = parser.parse(input, language: language)

        // Expect one child: HeaderNode
        XCTAssertEqual(result.root.children.count, 1)
        let header = result.root.children.first as? HeaderNode
        XCTAssertTrue(header != nil, "Expected a HeaderNode as first child")
        XCTAssertEqual(header?.level, 1) // Level 1 for single '#'

        // HeaderNode should contain a TextNode with content "Hello"
        let headerChildren = header?.children ?? []
        XCTAssertEqual(headerChildren.count, 1)
        if let textNode = headerChildren.first as? TextNode {
            XCTAssertEqual(textNode.content, "Hello")
        } else {
            XCTFail("Expected TextNode inside HeaderNode")
        }

        // No errors
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testTextBuilderAppendsTextNodeToRoot() {
        let input = "Hello World"
        let result = parser.parse(input, language: language)

        // Expect a paragraph with one TextNode
        XCTAssertEqual(result.root.children.count, 1)
        guard let para = result.root.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        if let textNode = para.children.first as? TextNode {
            XCTAssertEqual(textNode.content, "Hello World")
        } else {
            XCTFail("Expected TextNode inside Paragraph")
        }

        XCTAssertTrue(result.errors.isEmpty)
    }

    func testNewlineBuilderResetsContextToParent() {
        let input = "# Title\nSubtitle"
        let result = parser.parse(input, language: language)

        // After header parse, Title in HeaderNode, then newline resets context, Subtitle appended to root

        // Document should have two children: HeaderNode and ParagraphNode
        XCTAssertEqual(result.root.children.count, 2)
        XCTAssertTrue(result.root.children[0] is HeaderNode, "First child should be HeaderNode")
        guard let para = result.root.children[1] as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode after newline")
        }
        if let subtitleNode = para.children.first as? TextNode {
            XCTAssertEqual(subtitleNode.content, "Subtitle")
        } else {
            XCTFail("Expected Subtitle as TextNode")
        }

        XCTAssertTrue(result.errors.isEmpty)
    }
}

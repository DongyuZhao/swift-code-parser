import XCTest
@testable import SwiftParser

final class MarkdownTokenConsumerTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testHeadingConsumer_appendsHeaderNodeWithText() {
        let input = "# Hello"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        // Expect one child: HeaderNode
        XCTAssertEqual(node.children.count, 1)
        let header = node.children.first as? HeaderNode
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
        XCTAssertTrue(context.errors.isEmpty)
    }

    func testTextConsumer_appendsTextNodeToRoot() {
        let input = "Hello World"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        // Expect one TextNode appended to document
        XCTAssertEqual(node.children.count, 1)
        if let textNode = node.children.first as? TextNode {
            XCTAssertEqual(textNode.content, "Hello World")
        } else {
            XCTFail("Expected TextNode as child of DocumentNode")
        }

        XCTAssertTrue(context.errors.isEmpty)
    }

    func testNewlineConsumer_resetsContextToParent() {
        let input = "# Title\nSubtitle"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        // After header parse, Title in HeaderNode, then newline resets context, Subtitle appended to root

        // Document should have two children: HeaderNode and TextNode
        XCTAssertEqual(node.children.count, 2)
        XCTAssertTrue(node.children[0] is HeaderNode, "First child should be HeaderNode")
        XCTAssertTrue(node.children[1] is TextNode, "Second child should be TextNode after newline")

        // Check content of Subtitle
        if let subtitleNode = node.children[1] as? TextNode {
            XCTAssertEqual(subtitleNode.content, "Subtitle")
        } else {
            XCTFail("Expected Subtitle as TextNode")
        }

        XCTAssertTrue(context.errors.isEmpty)
    }
}

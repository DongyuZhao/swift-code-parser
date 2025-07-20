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

    func testHeadingConsumerAppendsHeaderNodeWithText() {
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

    func testTextConsumerAppendsTextNodeToRoot() {
        let input = "Hello World"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        // Expect a paragraph with one TextNode
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        if let textNode = para.children.first as? TextNode {
            XCTAssertEqual(textNode.content, "Hello World")
        } else {
            XCTFail("Expected TextNode inside Paragraph")
        }

        XCTAssertTrue(context.errors.isEmpty)
    }

    func testNewlineConsumerResetsContextToParent() {
        let input = "# Title\nSubtitle"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        // After header parse, Title in HeaderNode, then newline resets context, Subtitle appended to root

        // Document should have two children: HeaderNode and ParagraphNode
        XCTAssertEqual(node.children.count, 2)
        XCTAssertTrue(node.children[0] is HeaderNode, "First child should be HeaderNode")
        guard let para = node.children[1] as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode after newline")
        }
        if let subtitleNode = para.children.first as? TextNode {
            XCTAssertEqual(subtitleNode.content, "Subtitle")
        } else {
            XCTFail("Expected Subtitle as TextNode")
        }

        XCTAssertTrue(context.errors.isEmpty)
    }
}

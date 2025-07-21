import XCTest
@testable import SwiftParser

final class MarkdownNestedEmphasisTests: XCTestCase {
    private var parser: CodeOutdatedParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeOutdatedParser(language: language)
    }

    func testEmphasisWithLinkAndCode() {
        let input = "*see [link](url) `code`*"
        let root = language.root(of: input)
        let (node, ctx) = parser.parse(input, root: root)
        XCTAssertTrue(ctx.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode,
              let emph = para.children.first as? EmphasisNode else {
            return XCTFail("Expected EmphasisNode inside Paragraph")
        }
        XCTAssertEqual(emph.children.count, 4)
        XCTAssertTrue(emph.children[0] is TextNode)
        XCTAssertTrue(emph.children[1] is LinkNode)
        XCTAssertTrue(emph.children[2] is TextNode)
        XCTAssertTrue(emph.children[3] is InlineCodeNode)
    }

    func testStrongWithImageAndHTML() {
        let input = "**image ![alt](img.png) <b>bold</b>**"
        let root = language.root(of: input)
        let (node, ctx) = parser.parse(input, root: root)
        XCTAssertTrue(ctx.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode,
              let strong = para.children.first as? StrongNode else {
            return XCTFail("Expected StrongNode inside Paragraph")
        }
        XCTAssertEqual(strong.children.count, 4)
        XCTAssertTrue(strong.children[0] is TextNode)
        XCTAssertTrue(strong.children[1] is ImageNode)
        XCTAssertTrue(strong.children[2] is TextNode)
        XCTAssertTrue(strong.children[3] is HTMLNode)
    }
}

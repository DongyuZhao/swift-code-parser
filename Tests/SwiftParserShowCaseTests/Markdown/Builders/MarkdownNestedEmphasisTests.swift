import XCTest
@testable import SwiftParser
@testable import SwiftParserShowCase

final class MarkdownNestedEmphasisTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testEmphasisWithLinkAndCode() {
        let input = "*see [link](url) `code`*"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        guard let para = result.root.children.first as? ParagraphNode,
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
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        guard let para = result.root.children.first as? ParagraphNode,
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

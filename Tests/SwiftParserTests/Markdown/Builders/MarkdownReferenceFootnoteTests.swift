import XCTest
@testable import SwiftParser

final class MarkdownReferenceFootnoteTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testReferenceDefinition() {
        let input = "[ref]: https://example.com"
        let root = language.root(of: input)
        let (node, ctx) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(ctx.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        if let ref = node.children.first as? ReferenceNode {
            XCTAssertEqual(ref.identifier, "ref")
            XCTAssertEqual(ref.url, "https://example.com")
        } else {
            XCTFail("Expected ReferenceNode")
        }
    }

    func testFootnoteDefinitionAndReference() {
        let input = "[^1]: Footnote text\nParagraph with reference[^1]"
        let root = language.root(of: input)
        let (node, ctx) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(ctx.errors.isEmpty)
        XCTAssertEqual(node.children.count, 2)
        guard let footnote = node.children.first as? FootnoteNode else {
            return XCTFail("Expected FootnoteNode")
        }
        XCTAssertEqual(footnote.identifier, "1")
        XCTAssertEqual(footnote.content, "Footnote text")
        guard let paragraph = node.children.last as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertTrue(paragraph.children.contains { $0 is FootnoteNode })
    }
}

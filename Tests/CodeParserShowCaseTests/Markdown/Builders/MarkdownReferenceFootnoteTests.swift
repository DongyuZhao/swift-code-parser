import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

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
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        if let ref = result.root.children.first as? ReferenceNode {
            XCTAssertEqual(ref.identifier, "ref")
            XCTAssertEqual(ref.url, "https://example.com")
        } else {
            XCTFail("Expected ReferenceNode")
        }
    }

    func testFootnoteDefinitionAndReference() {
        let input = "[^1]: Footnote text\nParagraph with reference[^1]"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 2)
        guard let footnote = result.root.children.first as? FootnoteNode else {
            return XCTFail("Expected FootnoteNode")
        }
        XCTAssertEqual(footnote.identifier, "1")
        XCTAssertEqual(footnote.content, "Footnote text")
        guard let paragraph = result.root.children.last as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertTrue(paragraph.children.contains { $0 is FootnoteReferenceNode })
    }
}

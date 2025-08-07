import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownBlockElementTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testFencedCodeBlock() {
        let input = "```swift\nlet x = 1\n```"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        if let code = result.root.children.first as? CodeBlockNode {
            XCTAssertEqual(code.language, "swift")
        } else {
            XCTFail("Expected CodeBlockNode")
        }
    }

    func testHorizontalRule() {
        let input = "---"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertTrue(result.root.children.first is ThematicBreakNode)
    }

    func testUnorderedList() {
        let input = "- item"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        let list = result.root.children.first as? UnorderedListNode
        XCTAssertNotNil(list)
        XCTAssertEqual(list?.children().count, 1)
    }

    func testStrikethroughInline() {
        let input = "~~strike~~"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        guard let para = result.root.children.first as? ParagraphNode else { return XCTFail("Expected ParagraphNode") }
        XCTAssertTrue(para.children.first is StrikeNode)
    }

    func testFormulaBlock() {
        let input = "$$x=1$$"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.root.children.first is FormulaBlockNode)
    }

    func testDefinitionList() {
        let input = "Term\n: Definition"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        let list = result.root.children.first as? DefinitionListNode
        XCTAssertNotNil(list)
        XCTAssertEqual(list?.children().count, 1)
    }

    func testAdmonitionBlock() {
        let input = "> [!NOTE]\n> hello"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertTrue(result.root.children.first is AdmonitionNode)
    }

    func testCustomContainerBlock() {
        let input = "::: custom\nhello\n:::"
        let result = parser.parse(input, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertTrue(result.root.children.first is CustomContainerNode)
    }
}

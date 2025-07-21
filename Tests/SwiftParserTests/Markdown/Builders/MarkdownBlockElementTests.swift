import XCTest
@testable import SwiftParser

final class MarkdownBlockElementTests: XCTestCase {
    var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testFencedCodeBlock() {
        let input = "```swift\nlet x = 1\n```"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        if let code = node.children.first as? CodeBlockNode {
            XCTAssertEqual(code.language, "swift")
        } else {
            XCTFail("Expected CodeBlockNode")
        }
    }

    func testHorizontalRule() {
        let input = "---"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertTrue(node.children.first is ThematicBreakNode)
    }

    func testUnorderedList() {
        let input = "- item"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let list = node.children.first as? UnorderedListNode
        XCTAssertNotNil(list)
        XCTAssertEqual(list?.children().count, 1)
    }

    func testStrikethroughInline() {
        let input = "~~strike~~"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        guard let para = node.children.first as? ParagraphNode else { return XCTFail("Expected ParagraphNode") }
        XCTAssertTrue(para.children.first is StrikeNode)
    }

    func testFormulaBlock() {
        let input = "$$x=1$$"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertTrue(node.children.first is FormulaBlockNode)
    }

    func testDefinitionList() {
        let input = "Term\n: Definition"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let list = node.children.first as? DefinitionListNode
        XCTAssertNotNil(list)
        XCTAssertEqual(list?.children().count, 1)
    }

    func testAdmonitionBlock() {
        let input = "> [!NOTE]\n> hello"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertTrue(node.children.first is AdmonitionNode)
    }

    func testCustomContainerBlock() {
        let input = "::: custom\nhello\n:::"
        let root = language.root(of: input)
        let (node, context) = parser.outdatedParse(input, root: root)
        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertTrue(node.children.first is CustomContainerNode)
    }
}

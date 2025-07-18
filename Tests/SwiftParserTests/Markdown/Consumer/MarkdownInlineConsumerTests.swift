import XCTest
@testable import SwiftParser

final class MarkdownInlineConsumerTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testItalicConsumer_parsesItalicText() {
        let input = "*italic*"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let emph = node.children.first as? EmphasisNode
        XCTAssertNotNil(emph)
        XCTAssertEqual(emph?.children.count, 1)
        if let text = emph?.children.first as? TextNode {
            XCTAssertEqual(text.content, "italic")
        } else {
            XCTFail("Expected TextNode inside EmphasisNode")
        }
    }

    func testBoldConsumer_parsesStrongText() {
        let input = "**bold**"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let strong = node.children.first as? StrongNode
        XCTAssertNotNil(strong)
        XCTAssertEqual(strong?.children.count, 1)
        if let text = strong?.children.first as? TextNode {
            XCTAssertEqual(text.content, "bold")
        } else {
            XCTFail("Expected TextNode inside StrongNode")
        }
    }

    func testNestedEmphasis_parsesBoldAndItalic() {
        let input = "**bold *and italic***"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        guard let strong = node.children.first as? StrongNode else {
            return XCTFail("Expected StrongNode as root child")
        }
        // Strong should have children: TextNode("bold "), EmphasisNode
        XCTAssertEqual(strong.children.count, 2)
        if let textNode = strong.children[0] as? TextNode {
            XCTAssertEqual(textNode.content, "bold ")
        } else {
            XCTFail("Expected TextNode as first child of StrongNode")
        }
        if let emphasis = strong.children[1] as? EmphasisNode,
           let inner = emphasis.children.first as? TextNode {
            XCTAssertEqual(inner.content, "and italic")
        } else {
            XCTFail("Expected nested EmphasisNode with TextNode")
        }
    }

    func testInlineCodeConsumer_parsesInlineCode() {
        let input = "`code`"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let code = node.children.first as? InlineCodeNode
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.code, "code")
    }

    func testInlineFormulaConsumer_parsesFormula() {
        let input = "$x^2$"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let formula = node.children.first as? FormulaNode
        XCTAssertNotNil(formula)
        XCTAssertEqual(formula?.expression, "x^2")
    }

    func testAutolinkConsumer_parsesAutolink() {
        let urlString = "https://example.com"
        let input = "<\(urlString)>"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let link = node.children.first as? LinkNode
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.url, urlString)
        XCTAssertEqual(link?.title, urlString)
    }

    func testURLConsumer_parsesBareURL() {
        let urlString = "https://example.com"
        let input = urlString
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let link = node.children.first as? LinkNode
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.url, urlString)
        XCTAssertEqual(link?.title, urlString)
    }

    func testHTMLInlineConsumer_parsesEntityAndTag() {
        let input = "&amp;<b>bold</b>"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 2)
        // First is HTML entity
        let entity = node.children[0] as? HTMLNode
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.content, "&amp;")
        // Second is HTML tag
        let tag = node.children[1] as? HTMLNode
        XCTAssertNotNil(tag)
        // Name is not used for inline HTML
        XCTAssertEqual(tag?.content, "<b>bold</b>")
    }
    
    func testBlockquoteConsumer_parsesBlockquote() {
        let input = "> hello"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        let bq = node.children.first as? BlockquoteNode
        XCTAssertNotNil(bq)
        XCTAssertEqual(bq?.children.count, 1)
        if let text = bq?.children.first as? TextNode {
            XCTAssertEqual(text.content, "hello")
        } else {
            XCTFail("Expected TextNode inside BlockquoteNode")
        }
    }
}

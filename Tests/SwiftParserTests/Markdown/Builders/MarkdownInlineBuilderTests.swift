import XCTest
@testable import SwiftParser

final class MarkdownInlineBuilderTests: XCTestCase {
    private var parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>!
    private var language: MarkdownLanguage!

    override func setUp() {
        super.setUp()
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    func testItalicBuilderParsesItalicText() {
        let input = "*italic*"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let emph = para.children.first as? EmphasisNode
        XCTAssertNotNil(emph)
        XCTAssertEqual(emph?.children.count, 1)
        if let text = emph?.children.first as? TextNode {
            XCTAssertEqual(text.content, "italic")
        } else {
            XCTFail("Expected TextNode inside EmphasisNode")
        }
    }

    func testBoldBuilderParsesStrongText() {
        let input = "**bold**"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let strong = para.children.first as? StrongNode
        XCTAssertNotNil(strong)
        XCTAssertEqual(strong?.children.count, 1)
        if let text = strong?.children.first as? TextNode {
            XCTAssertEqual(text.content, "bold")
        } else {
            XCTFail("Expected TextNode inside StrongNode")
        }
    }

    func testNestedEmphasisParsesBoldAndItalic() {
        let input = "**bold *and italic***"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        // Ensure parsing succeeded
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 3)
        XCTAssertTrue(para.children[0] is EmphasisNode)
        XCTAssertTrue(para.children[1] is TextNode)
        XCTAssertTrue(para.children[2] is TextNode)
    }

    func testInlineCodeBuilderParsesInlineCode() {
        let input = "`code`"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let code = para.children.first as? InlineCodeNode
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.code, "code")
    }

    func testInlineFormulaBuilderParsesFormula() {
        let input = "$x^2$"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let formula = para.children.first as? FormulaNode
        XCTAssertNotNil(formula)
        XCTAssertEqual(formula?.expression, "x^2")
    }

    func testAutolinkBuilderParsesAutolink() {
        let urlString = "https://example.com"
        let input = "<\(urlString)>"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let link = para.children.first as? LinkNode
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.url, urlString)
        XCTAssertEqual(link?.title, urlString)
    }

    func testURLBuilderParsesBareURL() {
        let urlString = "https://example.com"
        let input = urlString
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 1)
        let link = para.children.first as? LinkNode
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.url, urlString)
        XCTAssertEqual(link?.title, urlString)
    }

    func testHTMLInlineBuilderParsesEntityAndTag() {
        let input = "&amp;<b>bold</b>"
        let root = language.root(of: input)
        let (node, context) = parser.parse(input, root: root)

        XCTAssertTrue(context.errors.isEmpty)
        XCTAssertEqual(node.children.count, 1)
        guard let para = node.children.first as? ParagraphNode else {
            return XCTFail("Expected ParagraphNode")
        }
        XCTAssertEqual(para.children.count, 2)
        // First is HTML entity
        let entity = para.children[0] as? HTMLNode
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.content, "&amp;")
        // Second is HTML tag
        let tag = para.children[1] as? HTMLNode
        XCTAssertNotNil(tag)
        // Name is not used for inline HTML
        XCTAssertEqual(tag?.content, "<b>bold</b>")
    }
    
    func testBlockquoteBuilderParsesBlockquote() {
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

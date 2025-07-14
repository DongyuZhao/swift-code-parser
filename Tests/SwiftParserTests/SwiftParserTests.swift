import XCTest
@testable import SwiftParser

final class SwiftParserTests: XCTestCase {

    func testParserInitialization() {
        let parser = SwiftParser()
        XCTAssertNotNil(parser)
    }

    func testPythonAssignment() {
        let parser = SwiftParser()
        let source = "x = 1"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? PythonLanguage.Element, PythonLanguage.Element.assignment)
    }

    func testMarkdownHeading() {
        let parser = SwiftParser()
        let source = "# Title\nHello"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 2)
    }

    func testMarkdownComplexATXHeading() {
        let parser = SwiftParser()
        let source = "### Complex ###\n"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .heading)
        XCTAssertEqual(result.root.children.first?.value, "Complex")
    }

    func testMarkdownSetextHeading() {
        let parser = SwiftParser()
        let source = "Title\n----\n"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .heading)
    }

    func testMarkdownListItem() {
        let parser = SwiftParser()
        let source = "- item1\n- item2"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 2)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .listItem)
    }

    func testMarkdownOrderedList() {
        let parser = SwiftParser()
        let source = "1. first\n2. second"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .orderedListItem)
    }

    func testMarkdownEmphasisAndStrong() {
        let parser = SwiftParser()
        let source = "*em* **strong**"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 3)
        XCTAssertEqual(result.root.children[0].type as? MarkdownLanguage.Element, .emphasis)
        XCTAssertEqual(result.root.children[2].type as? MarkdownLanguage.Element, .strong)
    }

    func testMarkdownNestedEmphasis() {
        let parser = SwiftParser()
        let source = "*a **b** c*"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let em = result.root.children.first
        XCTAssertEqual(em?.type as? MarkdownLanguage.Element, .emphasis)
        XCTAssertEqual(em?.children.count, 3)
        XCTAssertEqual(em?.children[1].type as? MarkdownLanguage.Element, .strong)
    }

    func testMarkdownCodeBlockAndInline() {
        let parser = SwiftParser()
        let source = "```\ncode\n```\ninline `code`"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .codeBlock)
        XCTAssertEqual(result.root.children.last?.type as? MarkdownLanguage.Element, .inlineCode)
    }

    func testMarkdownFencedCodeBlockWithInfo() {
        let parser = SwiftParser()
        let source = "```swift\nprint(\"hi\")\n```"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .codeBlock)
    }

    func testMarkdownTildeCodeBlock() {
        let parser = SwiftParser()
        let source = "~~~\nprint(\"hi\")\n~~~"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .codeBlock)
    }

    func testMarkdownLink() {
        let parser = SwiftParser()
        let source = "[title](url)"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .link)
    }

    func testMarkdownAutoLinkWithoutBrackets() {
        let parser = SwiftParser()
        let source = "https://example.com"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .autoLink)
        XCTAssertEqual(result.root.children.first?.value, "https://example.com")
    }

    func testMarkdownReferenceLink() {
        let parser = SwiftParser()
        let source = "[title][ref]\n[ref]: http://example.com"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .link)
    }

    func testMarkdownBlockQuote() {
        let parser = SwiftParser()
        let source = "> quote"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .blockQuote)
    }

    func testMarkdownImage() {
        let parser = SwiftParser()
        let source = "![alt](url)"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .image)
    }

    func testMarkdownEscapedCharacters() {
        let parser = SwiftParser()
        let source = "\\*not italic\\*"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.value, "*not italic*")
    }

    func testMarkdownEntityDecoding() {
        let parser = SwiftParser()
        let source = "&amp;&#35;&#x41;"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 3)
        XCTAssertEqual(result.root.children[0].value, "&")
        XCTAssertEqual(result.root.children[1].value, "#")
        XCTAssertEqual(result.root.children[2].value, "A")
    }

    func testPrattExpression() {
        let parser = SwiftParser()
        let source = "x = 1 + 2 * 3"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let assign = result.root.children.first
        XCTAssertEqual(assign?.children.first?.type as? PythonLanguage.Element, PythonLanguage.Element.expression)
    }

    func testStableNodeID() {
        let n1 = CodeNode(type: PythonLanguage.Element.identifier, value: "x")
        n1.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))

        let n2 = CodeNode(type: PythonLanguage.Element.identifier, value: "x")
        n2.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))

        XCTAssertEqual(n1.id, n2.id)
    }

    func testUnterminatedStringError() {
        let parser = SwiftParser()
        let source = "x = \"hello"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 1)
    }

    func testContextSnapshotRestore() {
        let tokenizer = PythonLanguage.Tokenizer()
        let tokens = tokenizer.tokenize("x = 1")
        let root = CodeNode(type: PythonLanguage.Element.root, value: "")
        var ctx = CodeContext(tokens: tokens, index: 0, currentNode: root, errors: [], input: "x = 1")
        let snap = ctx.snapshot()
        ctx.index = 2
        ctx.errors.append(CodeError("err"))
        ctx.currentNode.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))
        ctx.restore(snap)
        XCTAssertEqual(ctx.index, 0)
        XCTAssertEqual(ctx.errors.count, 0)
        XCTAssertEqual(root.children.count, 0)
    }

    func testIncrementalUpdateRollback() {
        let lang = PythonLanguage()
        let parser = CodeParser(tokenizer: lang.tokenizer, builders: lang.builders, expressionBuilders: lang.expressionBuilders)
        let root = CodeNode(type: lang.rootElement, value: "")
        _ = parser.parse("x = 1", rootNode: root)
        XCTAssertEqual(root.children.first?.children.first?.value, "1")
        _ = parser.update("x = 2", rootNode: root)
        XCTAssertEqual(root.children.first?.children.first?.value, "2")
    }

    func testUnregisterElementBuilder() {
        let tokenizer = PythonLanguage.Tokenizer()
        let expr = PythonLanguage.ExpressionBuilder()
        let assign = PythonLanguage.AssignmentBuilder(expressionBuilder: expr)
        let parser = CodeParser(tokenizer: tokenizer)
        parser.register(builder: assign)
        parser.register(expressionBuilder: expr)

        let root1 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("x = 1", rootNode: root1)
        XCTAssertEqual(root1.children.first?.type as? PythonLanguage.Element, .assignment)

        parser.unregister(builder: assign)

        let root2 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("x = 1", rootNode: root2)
        XCTAssertEqual(root2.children.first?.type as? PythonLanguage.Element, .identifier)
    }

    func testUnregisterExpressionBuilder() {
        let tokenizer = PythonLanguage.Tokenizer()
        let expr = PythonLanguage.ExpressionBuilder()
        let parser = CodeParser(tokenizer: tokenizer)
        parser.register(expressionBuilder: expr)

        let root1 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("1 + 2", rootNode: root1)
        XCTAssertEqual(root1.children.count, 1)

        parser.unregister(expressionBuilder: expr)

        let root2 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("1 + 2", rootNode: root2)
        XCTAssertEqual(root2.children.count, 0)
    }
}

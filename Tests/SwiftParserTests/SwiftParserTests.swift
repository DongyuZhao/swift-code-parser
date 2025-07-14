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
}

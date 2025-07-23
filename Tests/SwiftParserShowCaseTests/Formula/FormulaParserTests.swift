import XCTest
@testable import SwiftParser
@testable import SwiftParserShowCase

final class FormulaParserTests: XCTestCase {
    private var tokenizer: CodeTokenizer<FormulaTokenElement>!
    private var parser: CodeParser<FormulaNodeElement, FormulaTokenElement>!
    private var language: FormulaLanguage!

    override func setUp() {
        super.setUp()
        language = FormulaLanguage()
        let lang = language!
        tokenizer = CodeTokenizer(
            builders: lang.tokens,
            state: lang.state,
            eofTokenFactory: { range in lang.eofToken(at: range) }
        )
        parser = CodeParser(language: lang)
    }

    override func tearDown() {
        tokenizer = nil
        parser = nil
        language = nil
        super.tearDown()
    }

    func testTokenizeSimpleExpression() {
        let (tokens, errors) = tokenizer.tokenize("x+1")
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].element, .identifier)
        XCTAssertEqual(tokens[1].element, .plus)
        XCTAssertEqual(tokens[2].element, .number)
        XCTAssertEqual(tokens.last?.element, .eof)
    }

    func testParseSimpleExpression() {
        let result = parser.parse("x+1", language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        let expr = result.root.children.first as? BinaryOperationNode
        XCTAssertNotNil(expr)
        XCTAssertEqual(expr?.op, .plus)
        XCTAssertTrue(expr?.left is IdentifierNode)
        XCTAssertTrue(expr?.right is NumberNode)
    }

    func testParseCommand() {
        let result = parser.parse("\\frac{1}{2}", language: language)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.root.children.count, 1)
        let cmd = result.root.children.first as? CommandNode
        XCTAssertNotNil(cmd)
        XCTAssertEqual(cmd?.name, "\\frac")
        XCTAssertEqual(cmd?.arguments.count, 2)
    }

    func testDecimalNumberTokenization() {
        let (tokens, errors) = tokenizer.tokenize("3.14+2")
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].element, .number)
        XCTAssertEqual(tokens[0].text, "3.14")
        XCTAssertEqual(tokens[2].element, .number)
        XCTAssertEqual(tokens[2].text, "2")
    }

    func testParseExponent() {
        let result = parser.parse("x^2", language: language)
        XCTAssertTrue(result.errors.isEmpty)
        guard let op = result.root.children.first as? BinaryOperationNode else {
            XCTFail("Expected BinaryOperationNode"); return
        }
        XCTAssertEqual(op.op, .caret)
        XCTAssertTrue(op.left is IdentifierNode)
        XCTAssertTrue(op.right is NumberNode)
    }

    func testParseGroupedExpression() {
        let result = parser.parse("(1+2)*3", language: language)
        XCTAssertTrue(result.errors.isEmpty)
        guard let outer = result.root.children.first as? BinaryOperationNode else {
            XCTFail("Expected BinaryOperationNode"); return
        }
        XCTAssertEqual(outer.op, .times)
        let group = outer.left as? GroupNode
        XCTAssertNotNil(group)
    }

    func testParseNestedCommand() {
        let result = parser.parse("\\sqrt{1+2}", language: language)
        XCTAssertTrue(result.errors.isEmpty)
        guard let cmd = result.root.children.first as? CommandNode else {
            XCTFail("Expected CommandNode"); return
        }
        XCTAssertEqual(cmd.name, "\\sqrt")
        XCTAssertEqual(cmd.arguments.count, 1)
        XCTAssertTrue(cmd.arguments.first is BinaryOperationNode)
    }
}

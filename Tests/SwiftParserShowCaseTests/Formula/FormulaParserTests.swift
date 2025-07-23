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
}

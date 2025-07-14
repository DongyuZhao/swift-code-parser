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
}

import XCTest
@testable import SwiftParser
@testable import SwiftParserShowCase

final class MarkdownExporterTests: XCTestCase {
    func testExportSimpleMarkdown() {
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let markdown = """
# Title

Paragraph with `code`.

<div>HTML block</div>

$$ x^2 $$
"""
        let result = parser.parse(markdown, language: language)
        XCTAssertTrue(result.errors.isEmpty)
        let exporter = MarkdownExporter()
        guard let root = result.root as? MarkdownNodeBase else {
            return XCTFail("Invalid root node")
        }
        let html = exporter.export(result.root)
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<div>HTML block</div>"))
        XCTAssertTrue(html.contains("x^2"))
    }
}

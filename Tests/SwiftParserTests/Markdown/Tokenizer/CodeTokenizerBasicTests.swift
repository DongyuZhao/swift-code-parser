import XCTest
@testable import SwiftParser

final class CodeTokenizerBasicTests: XCTestCase {
    private var tokenizer: CodeTokenizer<MarkdownNodeElement, MarkdownTokenElement>!

    override func setUp() {
        let language = MarkdownLanguage()
        tokenizer = CodeTokenizer(language: language)
    }

    func testSingleCharacterToken() {
        let tokens = tokenizer.tokenize("#")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].element, .hash)
    }

    func testInlineCode() {
        let tokens = tokenizer.tokenize("`code`")
        XCTAssertFalse(tokens.isEmpty)
        XCTAssertEqual(tokens[0].element, .inlineCode)
        XCTAssertEqual(tokens[0].text, "`code`")
    }
}

import XCTest
@testable import SwiftParser

final class MarkdownCodeTokenizerBasicTests: XCTestCase {
    func testHeadingTokenization() {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
        let (tokens, _) = tokenizer.tokenize("# Title")
        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].element, .hash)
        XCTAssertEqual(tokens[1].element, .space)
        XCTAssertEqual(tokens[2].element, .text)
        XCTAssertEqual(tokens[3].element, .eof)
    }
}


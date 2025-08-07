import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownCodeTokenizerBasicTests: XCTestCase {
    func testHeadingTokenization() {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
        let (tokens, _) = tokenizer.tokenize("# Title")
        XCTAssertEqual(tokens.count, 4)
        XCTAssertEqual(tokens[0].element, .hash)
        XCTAssertEqual(tokens[1].element, .space)
        XCTAssertEqual(tokens[2].element, .text)
        XCTAssertEqual(tokens[3].element, .eof)
    }

    func testAutolinkTokenization() {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
        let (tokens, _) = tokenizer.tokenize("<https://example.com>")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .autolink)
        XCTAssertEqual(tokens[0].text, "<https://example.com>")
        XCTAssertEqual(tokens[1].element, .eof)
    }

    func testBareURLTokenization() {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
        let (tokens, _) = tokenizer.tokenize("https://example.com")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .url)
        XCTAssertEqual(tokens[1].element, .eof)
    }

    func testBareEmailTokenization() {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
        let (tokens, _) = tokenizer.tokenize("user@example.com")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .email)
        XCTAssertEqual(tokens[1].element, .eof)
    }
}

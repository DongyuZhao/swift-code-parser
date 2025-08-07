import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownCodeTokenizerCustomContainerTests: XCTestCase {
    private func tokenize(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
        let language = MarkdownLanguage()
        let tokenizer = CodeTokenizer(
            builders: language.tokens,
            state: language.state,
            eof: { language.eof(at: $0) }
        )
        let (tokens, _) = tokenizer.tokenize(input)
        return tokens
    }

    func testCustomContainerTokenization() {
        let input = "::: custom\ncontent\n:::"
        let tokens = tokenize(input)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .customContainer)
        XCTAssertEqual((tokens[0] as? MarkdownToken)?.text, input)
        XCTAssertEqual(tokens[1].element, .eof)
    }

    func testUnclosedCustomContainer() {
        let input = "::: name\ntext"
        let tokens = tokenize(input)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .customContainer)
        XCTAssertEqual((tokens[0] as? MarkdownToken)?.text, input)
        XCTAssertEqual(tokens[1].element, .eof)
    }
}

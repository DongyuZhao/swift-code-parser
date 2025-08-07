import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownCodeTokenizerFormulaTests: XCTestCase {
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

    func testDollarFormulas() {
        let cases: [(String, MarkdownTokenElement)] = [
            ("$math$", .formula),
            ("$$display$$", .formulaBlock)
        ]
        for (text, expected) in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, expected)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testTexFormulas() {
        let cases: [(String, MarkdownTokenElement)] = [
            ("\\(x\\)", .formula),
            ("\\[x\\]", .formulaBlock)
        ]
        for (text, expected) in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, expected)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testInlineFormulaInText() {
        let input = "Equation $x = y$ inside"
        let tokens = tokenize(input)
        XCTAssertTrue(tokens.contains { $0.element == .formula })
        XCTAssertEqual(tokens.last?.element, .eof)
    }

    func testInvalidInlineFormulaWithWhitespace() {
        let input = "$ x = y$"
        let tokens = tokenize(input)
        let elements = tokens.map { $0.element }
        XCTAssertFalse(elements.contains(.formula))
        XCTAssertTrue(elements.contains(.text))
        XCTAssertEqual(tokens.last?.element, .eof)
    }
}

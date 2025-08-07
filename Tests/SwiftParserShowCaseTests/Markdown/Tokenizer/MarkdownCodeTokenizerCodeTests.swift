import XCTest
@testable import SwiftParser
@testable import SwiftParserShowCase

final class MarkdownCodeTokenizerCodeTests: XCTestCase {
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

    func testInlineCode() {
        let cases: [(String, String)] = [
            ("`code`", "`code`"),
            ("`let x = 1`", "`let x = 1`"),
            ("`code with spaces`", "`code with spaces`"),
            ("`code`with`text`", "`code`")
        ]
        for (input, expectedText) in cases {
            let tokens = tokenize(input)
            XCTAssertEqual(tokens.first?.element, .inlineCode)
            XCTAssertEqual((tokens.first as? MarkdownToken)?.text, expectedText)
            XCTAssertEqual(tokens.last?.element, .eof)
        }
    }

    func testFencedCodeBlocks() {
        let cases: [String] = [
            "```\ncode\n```",
            "```swift\nlet x = 1\n```",
            "```\nfunction test() {\n  return 42;\n}\n```",
            "```python\nprint('hello')\n```"
        ]
        for input in cases {
            let tokens = tokenize(input)
            XCTAssertEqual(tokens.first?.element, .fencedCodeBlock)
            XCTAssertEqual((tokens.first as? MarkdownToken)?.text, input)
            XCTAssertEqual(tokens.last?.element, .eof)
        }
    }

    func testIndentedCodeBlocks() {
        let cases: [String] = [
            "    code line 1\n    code line 2",
            "\tcode with tab",
            "    let x = 42\n    print(x)"
        ]
        for input in cases {
            let tokens = tokenize(input)
            XCTAssertEqual(tokens.first?.element, .indentedCodeBlock)
            XCTAssertEqual((tokens.first as? MarkdownToken)?.text, input)
            XCTAssertEqual(tokens.last?.element, .eof)
        }
    }

    func testUnclosedFencedCodeBlock() {
        let input = "```\ncode without closing"
        let tokens = tokenize(input)
        XCTAssertEqual(tokens.first?.element, .fencedCodeBlock)
        XCTAssertEqual((tokens.first as? MarkdownToken)?.text, input)
        XCTAssertEqual(tokens.last?.element, .eof)
    }

    func testUnclosedInlineCode() {
        let input = "`code without closing"
        let tokens = tokenize(input)
        XCTAssertEqual(tokens.first?.element, .text)
        XCTAssertEqual((tokens.first as? MarkdownToken)?.text, "`")
        XCTAssertEqual(tokens.last?.element, .eof)
    }
}

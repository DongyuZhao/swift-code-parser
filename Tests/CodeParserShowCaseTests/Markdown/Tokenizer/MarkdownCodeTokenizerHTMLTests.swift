import XCTest
@testable import CodeParser
@testable import CodeParserShowCase

final class MarkdownCodeTokenizerHTMLTests: XCTestCase {
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

    func testHtmlTagVariations() {
        let cases: [(String, MarkdownTokenElement)] = [
            ("<p>", .htmlUnclosedBlock),
            ("<div>", .htmlUnclosedBlock),
            ("<span>", .htmlUnclosedBlock),
            ("<br />", .htmlTag),
            ("<hr />", .htmlTag),
            ("</p>", .htmlTag),
            ("</div>", .htmlTag),
            ("</span>", .htmlTag)
        ]
        for (text, expected) in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, expected)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testHtmlEntities() {
        let cases: [(String, MarkdownTokenElement)] = [
            ("&amp;", .htmlEntity),
            ("&lt;", .htmlEntity),
            ("&gt;", .htmlEntity),
            ("&quot;", .htmlEntity),
            ("&nbsp;", .htmlEntity),
            ("&copy;", .htmlEntity)
        ]
        for (text, expected) in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, expected)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testHtmlComments() {
        let cases: [String] = [
            "<!-- Simple comment -->",
            "<!--Multiple\nlines\ncomment-->",
            "<!-- Comment with &entities; -->"
        ]
        for text in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, .htmlComment)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testHtmlBlockElements() {
        let cases: [String] = [
            "<div>content</div>",
            "<p>paragraph</p>",
            "<strong>bold</strong>",
            "<em>italic</em>",
            "<code>code</code>"
        ]
        for text in cases {
            let tokens = tokenize(text)
            XCTAssertEqual(tokens.count, 2)
            XCTAssertEqual(tokens[0].element, .htmlBlock)
            XCTAssertEqual(tokens[0].text, text)
            XCTAssertEqual(tokens[1].element, .eof)
        }
    }

    func testMixedHtmlAndMarkdown() {
        let text = "Text with <strong>bold</strong> and *emphasis*"
        let tokens = tokenize(text)
        let expected: [MarkdownTokenElement] = [.text, .space, .text, .space, .htmlBlock, .space, .text, .space, .asterisk, .text, .asterisk, .eof]
        XCTAssertEqual(tokens.map { $0.element }, expected)
    }

    func testInvalidHtmlLikeContent() {
        let text = "< not a tag > and < another"
        let tokens = tokenize(text)
        let expected: [MarkdownTokenElement] = [.lt, .space, .text, .space, .text, .space, .text, .space, .gt, .space, .text, .space, .lt, .space, .text, .eof]
        XCTAssertEqual(tokens.map { $0.element }, expected)
    }
}

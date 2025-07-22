import XCTest
@testable import SwiftParser

final class MarkdownTokenizerHTMLTests: XCTestCase {

    private var tokenizer: CodeTokenizer<MarkdownTokenElement>!

    override func setUp() {
        super.setUp()
        let language = MarkdownLanguage()
        tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
    }

    override func tearDown() {
        tokenizer = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Helper to assert token properties
    private func assertToken(
        at index: Int,
        in tokens: [any CodeToken<MarkdownTokenElement>],
        expectedElement: MarkdownTokenElement,
        expectedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard index < tokens.count else {
            XCTFail("Index \(index) out of bounds for tokens array with count \(tokens.count)", file: file, line: line)
            return
        }
        
        let token = tokens[index]
        XCTAssertEqual(token.element, expectedElement, "Token element mismatch at index \(index)", file: file, line: line)
        XCTAssertEqual(token.text, expectedText, "Token text mismatch at index \(index)", file: file, line: line)
    }
    
    // MARK: - HTML Tag Tests
    
    func testHtmlTagVariations() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("<p>", .htmlUnclosedBlock),
            ("<div>", .htmlUnclosedBlock),
            ("<span>", .htmlUnclosedBlock),
            ("<br />", .htmlTag),
            ("<hr />", .htmlTag),
            ("</p>", .htmlTag),
            ("</div>", .htmlTag),
            ("</span>", .htmlTag)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for HTML tag '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testHtmlEntities() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("&amp;", .htmlEntity),
            ("&lt;", .htmlEntity),
            ("&gt;", .htmlEntity),
            ("&quot;", .htmlEntity),
            ("&nbsp;", .htmlEntity),
            ("&copy;", .htmlEntity)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for HTML entity '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testHtmlComments() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("<!-- Simple comment -->", .htmlComment),
            ("<!--Multiple\nlines\ncomment-->", .htmlComment),
            ("<!-- Comment with &entities; -->", .htmlComment)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for HTML comment '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testHtmlBlockElements() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("<div>content</div>", .htmlBlock),
            ("<p>paragraph</p>", .htmlBlock),
            ("<strong>bold</strong>", .htmlBlock),
            ("<em>italic</em>", .htmlBlock),
            ("<code>code</code>", .htmlBlock)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for HTML block '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testMixedHtmlAndMarkdown() {
        let text = "Text with <strong>bold</strong> and *emphasis*"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .text, .space, .text, .space, .htmlBlock, .space, .text, .space, .asterisk, .text, .asterisk, .eof
        ]
        
        XCTAssertEqual(tokens.count, expectedElements.count)
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testInvalidHtmlLikeContent() {
        let text = "< not a tag > and < another"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .lt, .space, .text, .space, .text, .space, .text, .space, .gt, .space, .text, .space, .lt, .space, .text, .eof
        ]
        
        XCTAssertEqual(tokens.count, expectedElements.count)
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
}
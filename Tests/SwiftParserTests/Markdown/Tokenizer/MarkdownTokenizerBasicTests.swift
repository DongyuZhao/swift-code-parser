import XCTest
@testable import SwiftParser

final class MarkdownTokenizerBasicTests: XCTestCase {

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
    
    /// Helper to get token elements as array
    private func getTokenElements(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownTokenElement] {
        return tokens.map { $0.element }
    }
    
    /// Helper to get token texts as array
    private func getTokenTexts(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [String] {
        return tokens.map { $0.text }
    }
    
    /// Helper to print tokens for debugging
    private func printTokens(_ tokens: [any CodeToken<MarkdownTokenElement>], input: String) {
        print("Input: '\(input)'")
        print("Number of tokens: \(tokens.count)")
        for (index, token) in tokens.enumerated() {
            print("Token \(index): \(token.element) - '\(token.text)'")
        }
    }
    
    // MARK: - Basic Token Tests
    
    func testSingleCharacterTokens() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("#", .hash),
            ("*", .asterisk),
            ("_", .underscore),
            ("`", .text),
            ("-", .dash),
            ("+", .plus),
            ("=", .equals),
            ("~", .tilde),
            ("|", .pipe),
            (":", .colon),
            ("!", .exclamation),
            ("$", .text) // Dollar sign treated as text
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for input '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testPairedTokens() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("[]", [.leftBracket, .rightBracket]),
            ("()", [.leftParen, .rightParen]),
            ("{}", [.leftBrace, .rightBrace]),
            ("<>", [.lt, .gt])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count + 1, "Expected \(expectedElements.count + 1) tokens for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                assertToken(at: index, in: tokens, expectedElement: expectedElement, expectedText: String(input[input.index(input.startIndex, offsetBy: index)]))
            }
            assertToken(at: expectedElements.count, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    // MARK: - Whitespace Tests
    
    func testWhitespaceTokens() {
        let testCases: [(String, MarkdownTokenElement)] = [
            (" ", .space),
            ("\t", .tab),
            ("\n", .newline),
            ("\r", .carriageReturn)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for whitespace input")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testCRLFHandling() {
        let text = "\r\n"
        let (tokens, _) = tokenizer.tokenize(text)
        
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .newline)
        XCTAssertEqual(tokens[0].text, "\r\n")
        XCTAssertEqual(tokens[1].element, .eof)
    }
    
    func testMultipleWhitespace() {
        let text = "   \t\n  "
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .space, .space, .space, .tab, .newline, .space, .space, .eof
        ]
        
        XCTAssertEqual(tokens.count, expectedElements.count)
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    // MARK: - Text and Number Tests
    
    func testTextTokens() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("a", .text),
            ("hello", .text),
            ("café", .text),
            ("🚀", .text),
            ("中文", .text),
            ("abc123", .text),
            ("123abc", .text)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for input '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testNumberTokens() {
        let testCases = ["123", "456", "789"]
        
        for input in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for number input '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: .number, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testMixedAlphanumericTokens() {
        let text = "abc-123"
        let (tokens, _) = tokenizer.tokenize(text)
        
        XCTAssertEqual(tokens.count, 4) // "abc" + "-" + "123" + eof
        assertToken(at: 0, in: tokens, expectedElement: .text, expectedText: "abc")
        assertToken(at: 1, in: tokens, expectedElement: .dash, expectedText: "-")
        assertToken(at: 2, in: tokens, expectedElement: .number, expectedText: "123")
        assertToken(at: 3, in: tokens, expectedElement: .eof, expectedText: "")
    }
    
    // MARK: - Basic Markdown Syntax Tests
    
    func testMarkdownHeadings() {
        let text = "# Hello"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [.hash, .space, .text, .eof]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testMarkdownLinks() {
        let text = "[link](url)"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof
        ]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testMarkdownImages() {
        let text = "![alt](src)"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .exclamation, .leftBracket, .text, .rightBracket, .leftParen, .text, .rightParen, .eof
        ]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testMarkdownEmphasis() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("*italic*", [.asterisk, .text, .asterisk, .eof]),
            ("**bold**", [.asterisk, .asterisk, .text, .asterisk, .asterisk, .eof]),
            ("_underline_", [.underscore, .text, .underscore, .eof])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count, "Failed for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch for input '\(input)'")
            }
        }
    }
    
    func testMarkdownCode() {
        let text = "`code`"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [.inlineCode, .eof]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
        
        // Check the full text of the inline code token
        XCTAssertEqual(tokens[0].text, "`code`", "Inline code token should contain the full text")
    }
    
    func testMarkdownBlockquote() {
        let text = "> Quote"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [.gt, .space, .text, .eof]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testMarkdownLists() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("- Item", [.dash, .space, .text, .eof]),
            ("+ Item", [.plus, .space, .text, .eof]),
            ("1. Item", [.number, .dot, .space, .text, .eof])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count, "Failed for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch for input '\(input)'")
            }
        }
    }
    
    // MARK: - GitHub Flavored Markdown Tests
    
    func testGFMTable() {
        let text = "| A | B |"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .pipe, .space, .text, .space, .pipe, .space, .text, .space, .pipe, .eof
        ]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testGFMStrikethrough() {
        let text = "~~strike~~"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let expectedElements: [MarkdownTokenElement] = [
            .tilde, .tilde, .text, .tilde, .tilde, .eof
        ]
        XCTAssertEqual(tokens.count, expectedElements.count)
        
        for (index, expectedElement) in expectedElements.enumerated() {
            XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch")
        }
    }
    
    func testGFMTaskLists() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("- [ ] Task", [.dash, .space, .leftBracket, .space, .rightBracket, .space, .text, .eof]),
            ("- [x] Done", [.dash, .space, .leftBracket, .text, .rightBracket, .space, .text, .eof])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count, "Failed for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch for input '\(input)'")
            }
        }
    }
    
    // MARK: - Code Block and Inline Code Tests
    
    func testInlineCodeTokenization() {
        let testCases: [(String, String)] = [
            ("`code`", "`code`"),
            ("`let x = 1`", "`let x = 1`"),
            ("`code with spaces`", "`code with spaces`"),
            ("`code`with`text`", "`code`"),  // Should only capture the first inline code
        ]
        
        for (input, expectedText) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertGreaterThan(tokens.count, 0, "Should have at least one token for input: \(input)")
            
            let firstToken = tokens[0]
            XCTAssertEqual(firstToken.element, .inlineCode, "First token should be inline code for input: \(input)")
            XCTAssertEqual(firstToken.text, expectedText, "Token text should match expected for input: \(input)")
        }
    }
    
    func testCodeBlockTokenization() {
        let testCases: [(String, String)] = [
            ("```\ncode\n```", "```\ncode\n```"),
            ("```swift\nlet x = 1\n```", "```swift\nlet x = 1\n```"),
            ("```\nfunction test() {\n  return 42;\n}\n```", "```\nfunction test() {\n  return 42;\n}\n```"),
            ("```python\nprint('hello')\n```", "```python\nprint('hello')\n```"),
        ]
        
        for (input, expectedText) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertGreaterThan(tokens.count, 0, "Should have at least one token for input: \(input)")
            
            let firstToken = tokens[0]
            XCTAssertEqual(firstToken.element, .fencedCodeBlock, "First token should be fenced code block for input: \(input)")
            XCTAssertEqual(firstToken.text, expectedText, "Token text should match expected for input: \(input)")
        }
    }
    
    func testIndentedCodeBlockTokenization() {
        let testCases: [(String, String)] = [
            ("    code line 1\n    code line 2", "    code line 1\n    code line 2"),
            ("\tcode with tab", "\tcode with tab"),
            ("    let x = 42\n    print(x)", "    let x = 42\n    print(x)"),
        ]
        
        for (input, expectedText) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertGreaterThan(tokens.count, 0, "Should have at least one token for input: \(input)")
            
            let firstToken = tokens[0]
            XCTAssertEqual(firstToken.element, .indentedCodeBlock, "First token should be indented code block for input: \(input)")
            XCTAssertEqual(firstToken.text, expectedText, "Token text should match expected for input: \(input)")
        }
    }
    
    func testUnclosedCodeBlock() {
        let input = "```\ncode without closing"
        let (tokens, _) = tokenizer.tokenize(input)
        
        XCTAssertGreaterThan(tokens.count, 0, "Should have at least one token")
        
        let firstToken = tokens[0]
        XCTAssertEqual(firstToken.element, .fencedCodeBlock, "Should be treated as fenced code block")
        XCTAssertEqual(firstToken.text, input, "Should capture all text until EOF")
    }
    
    func testUnclosedInlineCode() {
        let input = "`code without closing"
        let (tokens, _) = tokenizer.tokenize(input)
        
        // Should fall back to individual backtick token
        XCTAssertGreaterThan(tokens.count, 0, "Should have at least one token")
        
        let firstToken = tokens[0]
        XCTAssertEqual(firstToken.element, .text, "Should be treated as backtick when unclosed")
        XCTAssertEqual(firstToken.text, "`", "Should be just the backtick")
    }

    func testCustomContainerTokenization() {
        let input = "::: custom\ncontent\n:::"
        let (tokens, _) = tokenizer.tokenize(input)

        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].element, .customContainer)
        XCTAssertEqual(tokens[0].text, input)
        XCTAssertEqual(tokens[1].element, .eof)
    }

    // MARK: - Edge Cases and Special Scenarios
    
    func testEmptyAndWhitespaceInputs() {
        let testCases: [(String, Int)] = [
            ("", 1), // EOF only
            ("   ", 4), // 3 spaces + EOF
            ("   \t\n  ", 8) // 3 spaces + tab + newline + 2 spaces + EOF
        ]
        
        for (input, expectedCount) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedCount, "Failed for input '\(input)'")
            XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF")
        }
    }
    
    func testSpecialCharacters() {
        let text = "!@#$%^&*()_+-=[]{}|;:'\",.<>?/~`"
        let (tokens, _) = tokenizer.tokenize(text)
        
        // Should tokenize each character individually and end with EOF
        XCTAssertEqual(tokens.count, 32) // 31 chars + EOF
        XCTAssertEqual(tokens.last?.element, .eof)

        // Test some key characters are properly recognized
        XCTAssertEqual(tokens[0].element, .exclamation)
        XCTAssertEqual(tokens[1].element, .atSign)
        XCTAssertEqual(tokens[2].element, .hash)
        XCTAssertEqual(tokens[5].element, .caret)
        XCTAssertEqual(tokens[6].element, .ampersand)
        XCTAssertEqual(tokens[7].element, .asterisk)
    }
    
    func testUnicodeCharacters() {
        let text = "café 🚀 中文"
        let (tokens, _) = tokenizer.tokenize(text)
        
        XCTAssertTrue(tokens.count > 1, "Should produce multiple tokens")
        XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF")
    }
    
    func testTokenRanges() {
        let text = "abc"
        let (tokens, _) = tokenizer.tokenize(text)
        
        XCTAssertEqual(tokens.count, 2) // "abc" + EOF
        XCTAssertEqual(tokens[0].range, text.startIndex..<text.endIndex)
        XCTAssertEqual(tokens[1].range, text.endIndex..<text.endIndex) // EOF range
    }
    
    // MARK: - Token Utilities Tests
    
    func testTokenUtilities() {
        let text = "* _test_ `code` \n"
        let (tokens, _) = tokenizer.tokenize(text)
        
        // Test asterisk token properties
        guard let asteriskTokenBase = tokens.first(where: { $0.element == .asterisk }),
              let asteriskToken = asteriskTokenBase as? MarkdownToken else {
            XCTFail("Expected to find asterisk token")
            return
        }
        
        XCTAssertTrue(asteriskToken.isEmphasisDelimiter)
        XCTAssertFalse(asteriskToken.isWhitespace)
        XCTAssertTrue(asteriskToken.canStartBlock)
        XCTAssertFalse(asteriskToken.isMathDelimiter)
        XCTAssertFalse(asteriskToken.isTableDelimiter)
        
        // Test underscore token properties
        guard let underscoreTokenBase = tokens.first(where: { $0.element == .underscore }),
              let underscoreToken = underscoreTokenBase as? MarkdownToken else {
            XCTFail("Expected to find underscore token")
            return
        }
        
        XCTAssertTrue(underscoreToken.isEmphasisDelimiter)
        XCTAssertFalse(underscoreToken.isWhitespace)
        
        // Test space token properties
        guard let spaceTokenBase = tokens.first(where: { $0.element == .space }),
              let spaceToken = spaceTokenBase as? MarkdownToken else {
            XCTFail("Expected to find space token")
            return
        }
        
        XCTAssertFalse(spaceToken.isEmphasisDelimiter)
        XCTAssertTrue(spaceToken.isWhitespace)
        XCTAssertFalse(spaceToken.isLineEnding)
        
        // Test newline token properties
        guard let newlineTokenBase = tokens.first(where: { $0.element == .newline }),
              let newlineToken = newlineTokenBase as? MarkdownToken else {
            XCTFail("Expected to find newline token")
            return
        }
        
        XCTAssertTrue(newlineToken.isWhitespace)
        XCTAssertTrue(newlineToken.isLineEnding)
        
        // Test inline code token properties
        guard let inlineCodeTokenBase = tokens.first(where: { $0.element == .inlineCode }),
              let inlineCodeToken = inlineCodeTokenBase as? MarkdownToken else {
            XCTFail("Expected to find inline code token")
            return
        }
        
        XCTAssertFalse(inlineCodeToken.isEmphasisDelimiter)
        XCTAssertFalse(inlineCodeToken.isWhitespace)
        XCTAssertTrue(inlineCodeToken.canStartBlock)
        XCTAssertFalse(inlineCodeToken.isMathDelimiter)
        XCTAssertFalse(inlineCodeToken.isTableDelimiter)
    }
}

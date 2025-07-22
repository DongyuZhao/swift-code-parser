import XCTest
@testable import SwiftParser

final class MarkdownTokenizerFormulaTests: XCTestCase {

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
    
    // MARK: - Dollar Math Formula Tests
    
    func testDollarMathFormulas() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("$math$", [.formula, .eof]),
            ("$$display$$", [.formulaBlock, .eof])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count, "Failed for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch for input '\(input)'")
            }
        }
    }
    
    func testTexMathFormulas() {
        let testCases: [(String, [MarkdownTokenElement])] = [
            ("\\(x^2\\)", [.formula, .eof]),
            ("\\[E = mc^2\\]", [.formulaBlock, .eof])
        ]
        
        for (input, expectedElements) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, expectedElements.count, "Failed for input '\(input)'")
            
            for (index, expectedElement) in expectedElements.enumerated() {
                XCTAssertEqual(tokens[index].element, expectedElement, "Token \(index) element mismatch for input '\(input)'")
            }
        }
    }
    
    func testInlineMathFormulas() {
        let testCases: [(String, String)] = [
            ("This is an inline math formula: $x = y + z$ and more text", "$x = y + z$"),
            ("Formula with escaped dollar: $x = \\$100$ end", "$x = \\$100$"),
            ("Multiple formulas: $a = b$ and $c = d$ here", "$a = b$")
        ]
        
        for (input, expectedMath) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let mathTokens = tokens.filter { $0.element == .formula }
            XCTAssertGreaterThan(mathTokens.count, 0, "Should find math tokens in: \(input)")
            
            if let mathToken = mathTokens.first as? MarkdownToken {
                XCTAssertEqual(mathToken.text, expectedMath, "Math token text mismatch")
                XCTAssertTrue(mathToken.isInlineMath, "Should be inline math")
                XCTAssertTrue(mathToken.isMathFormula, "Should be math formula")
            }
        }
    }
    
    func testDisplayMathFormulas() {
        let testCases: [(String, String)] = [
            ("$$x = y + z$$", "$$x = y + z$$"),
            ("Display: $$E = mc^2$$ equation", "$$E = mc^2$$"),
            ("\\[x^2 + y^2 = z^2\\]", "\\[x^2 + y^2 = z^2\\]")
        ]
        
        for (input, expectedMath) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let mathTokens = tokens.filter { $0.element == .formulaBlock }
            XCTAssertGreaterThan(mathTokens.count, 0, "Should find display math tokens in: \(input)")
            
            if let mathToken = mathTokens.first as? MarkdownToken {
                XCTAssertEqual(mathToken.text, expectedMath, "Math token text mismatch")
                XCTAssertTrue(mathToken.isDisplayMath, "Should be display math")
                XCTAssertTrue(mathToken.isMathFormula, "Should be math formula")
            }
        }
    }
    
    func testMathInTextContext() {
        let text = "This is \\(inline\\) and \\[display\\] math."
        let (tokens, _) = tokenizer.tokenize(text)
        
        let elements = getTokenElements(tokens)
        let texts = getTokenTexts(tokens)
        
        XCTAssertTrue(elements.contains(.formula), "Should contain inline formula")
        XCTAssertTrue(elements.contains(.formulaBlock), "Should contain display formula")
        XCTAssertTrue(texts.contains("\\(inline\\)"), "Should contain inline formula text")
        XCTAssertTrue(texts.contains("\\[display\\]"), "Should contain display formula text")
    }
    
    // MARK: - Math Formula Variations
    
    func testSimpleMathExpressions() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("$x$", .formula),
            ("$a = b$", .formula),
            ("$x + y = z$", .formula),
            ("$\\alpha + \\beta$", .formula),
            ("$\\frac{1}{2}$", .formula),
            ("$x^2$", .formula),
            ("$x_1$", .formula),
            ("$\\sqrt{x}$", .formula)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for math formula '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testComplexMathExpressions() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("$$\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}$$", .formulaBlock),
            ("$$\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}$$", .formulaBlock),
            ("$$\\lim_{x \\to 0} \\frac{\\sin x}{x} = 1$$", .formulaBlock),
            ("$$\\begin{matrix} a & b \\\\ c & d \\end{matrix}$$", .formulaBlock),
            ("$$f(x) = \\begin{cases} x^2 & \\text{if } x \\geq 0 \\\\ -x^2 & \\text{if } x < 0 \\end{cases}$$", .formulaBlock)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for complex math formula '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testTexStyleMathFormulas() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("\\(x\\)", .formula),
            ("\\(a = b\\)", .formula),
            ("\\(x + y = z\\)", .formula),
            ("\\(\\alpha + \\beta\\)", .formula),
            ("\\(\\frac{1}{2}\\)", .formula),
            ("\\[x^2\\]", .formulaBlock),
            ("\\[a = b\\]", .formulaBlock),
            ("\\[x + y = z\\]", .formulaBlock),
            ("\\[\\alpha + \\beta\\]", .formulaBlock),
            ("\\[\\frac{1}{2}\\]", .formulaBlock)
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for TeX math formula '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    // MARK: - Math Formula Edge Cases
    
    func testEmptyMathFormulas() {
        let testCases: [(String, MarkdownTokenElement, Int)] = [
            ("$$", .formulaBlock, 2), // Two dollar signs treated as empty display math
            ("$$$$", .formulaBlock, 2), // Four dollar signs is empty display math
            ("$ $", .text, 4), // Space between dollars is treated as separate tokens
            ("$$ $$", .formulaBlock, 2), // Spaces between double dollars is display math
            ("\\(\\)", .formula, 2), // Empty TeX inline math
            ("\\[\\]", .formulaBlock, 2) // Empty TeX display math
        ]
        
        for (input, expectedElement, expectedCount) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            
            if input == "$ $" {
                // For "$ $", it should be treated as separate tokens
                XCTAssertEqual(tokens.count, expectedCount, "Expected \(expectedCount) tokens for '\(input)'")
                assertToken(at: 0, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 1, in: tokens, expectedElement: .space, expectedText: " ")
                assertToken(at: 2, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 3, in: tokens, expectedElement: .eof, expectedText: "")
            } else {
                // For proper math formulas
                XCTAssertEqual(tokens.count, expectedCount, "Expected \(expectedCount) tokens for math formula '\(input)'")
                assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
                assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
            }
        }
    }
    
    func testMathFormulasWithSpecialCharacters() {
        let testCases: [(String, MarkdownTokenElement)] = [
            ("$x = \\$100$", .formula), // Escaped dollar sign
            ("$a \\& b$", .formula), // Escaped ampersand
            ("$x \\% y$", .formula), // Escaped percent
            ("$a \\# b$", .formula), // Escaped hash
            ("$x \\{ y \\}$", .formula), // Escaped braces
            ("$a \\[ b \\]$", .formula), // Escaped brackets
            ("$x \\( y \\)$", .formula), // Escaped parentheses
            ("$\\text{Hello, World!}$", .formula) // Text with punctuation
        ]
        
        for (input, expectedElement) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            XCTAssertEqual(tokens.count, 2, "Expected 2 tokens for math formula with special chars '\(input)'")
            assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
            assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
        }
    }
    
    func testMathFormulasWithWhitespace() {
        let testCases: [(String, MarkdownTokenElement, Int)] = [
            ("$ x = y $", .text, 10), // Spaces around content - not valid inline math
            ("$$\n  x = y\n$$", .formulaBlock, 2), // Newlines and spaces in display math
            ("\\( x = y \\)", .formula, 2), // Spaces in TeX inline
            ("\\[\n  x = y\n\\]", .formulaBlock, 2), // Newlines in TeX display
            ("$x\n=\ny$", .text, 8), // Newlines in content - not valid inline math
            ("$$x\t=\ty$$", .formulaBlock, 2) // Tabs in display math
        ]
        
        for (input, expectedElement, expectedCount) in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            
            if input == "$ x = y $" {
                // This should be treated as separate tokens because inline math can't start with whitespace
                XCTAssertEqual(tokens.count, expectedCount, "Expected \(expectedCount) tokens for '\(input)'")
                assertToken(at: 0, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 1, in: tokens, expectedElement: .space, expectedText: " ")
                assertToken(at: 2, in: tokens, expectedElement: .text, expectedText: "x")
                assertToken(at: 3, in: tokens, expectedElement: .space, expectedText: " ")
                assertToken(at: 4, in: tokens, expectedElement: .equals, expectedText: "=")
                assertToken(at: 5, in: tokens, expectedElement: .space, expectedText: " ")
                assertToken(at: 6, in: tokens, expectedElement: .text, expectedText: "y")
                assertToken(at: 7, in: tokens, expectedElement: .space, expectedText: " ")
                assertToken(at: 8, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 9, in: tokens, expectedElement: .eof, expectedText: "")
            } else if input == "$x\n=\ny$" {
                // This should be treated as separate tokens because inline math can't span newlines
                XCTAssertEqual(tokens.count, expectedCount, "Expected \(expectedCount) tokens for '\(input)'")
                assertToken(at: 0, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 1, in: tokens, expectedElement: .text, expectedText: "x")
                assertToken(at: 2, in: tokens, expectedElement: .newline, expectedText: "\n")
                assertToken(at: 3, in: tokens, expectedElement: .equals, expectedText: "=")
                assertToken(at: 4, in: tokens, expectedElement: .newline, expectedText: "\n")
                assertToken(at: 5, in: tokens, expectedElement: .text, expectedText: "y")
                assertToken(at: 6, in: tokens, expectedElement: .text, expectedText: "$")
                assertToken(at: 7, in: tokens, expectedElement: .eof, expectedText: "")
            } else {
                // For proper math formulas
                XCTAssertEqual(tokens.count, expectedCount, "Expected \(expectedCount) tokens for math formula '\(input)'")
                assertToken(at: 0, in: tokens, expectedElement: expectedElement, expectedText: input)
                assertToken(at: 1, in: tokens, expectedElement: .eof, expectedText: "")
            }
        }
    }
    
    // MARK: - Non-Math Backslash Tests
    
    func testNonMathBackslash() {
        let text = "\\n and \\t and \\x"
        let (tokens, _) = tokenizer.tokenize(text)
        
        let elements = getTokenElements(tokens)
        
        XCTAssertFalse(elements.contains(.formula), "Should not contain formula tokens")
        XCTAssertFalse(elements.contains(.formulaBlock), "Should not contain formula block tokens")
        XCTAssertTrue(elements.contains(.backslash), "Should contain backslash tokens")
    }
    
    func testBackslashWithoutMath() {
        let testCases = [
            "\\a",
            "\\b",
            "\\c",
            "\\d",
            "\\e",
            "\\f",
            "\\g",
            "\\h",
            "\\i",
            "\\j",
            "\\k",
            "\\l",
            "\\m",
            "\\n",
            "\\o",
            "\\p",
            "\\q",
            "\\r",
            "\\s",
            "\\t",
            "\\u",
            "\\v",
            "\\w",
            "\\x",
            "\\y",
            "\\z"
        ]
        
        for input in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let elements = getTokenElements(tokens)
            
            XCTAssertFalse(elements.contains(.formula), "Should not contain formula tokens for '\(input)'")
            XCTAssertFalse(elements.contains(.formulaBlock), "Should not contain formula block tokens for '\(input)'")
            XCTAssertTrue(elements.contains(.backslash), "Should contain backslash tokens for '\(input)'")
        }
    }
    
    // MARK: - Math Formula Token Utilities
    
    func testMathTokenUtilities() {
        let formulaToken = MarkdownToken.formula("$x$", at: "".startIndex..<"".startIndex)
        let formulaBlockToken = MarkdownToken.formulaBlock("$$x$$", at: "".startIndex..<"".startIndex)
        let textToken = MarkdownToken.text("hello", at: "".startIndex..<"".startIndex)
        
        // Test math formula detection
        XCTAssertTrue(formulaToken.isMathFormula)
        XCTAssertTrue(formulaBlockToken.isMathFormula)
        XCTAssertFalse(textToken.isMathFormula)
        
        // Test inline/display math detection
        XCTAssertTrue(formulaToken.isInlineMath)
        XCTAssertFalse(formulaBlockToken.isInlineMath)
        XCTAssertFalse(textToken.isInlineMath)
        
        XCTAssertFalse(formulaToken.isDisplayMath)
        XCTAssertTrue(formulaBlockToken.isDisplayMath)
        XCTAssertFalse(textToken.isDisplayMath)
        
        // Math delimiters no longer exist - all should be false
        XCTAssertFalse(formulaToken.isMathDelimiter)
        XCTAssertFalse(formulaBlockToken.isMathDelimiter)
        XCTAssertFalse(textToken.isMathDelimiter)
    }
    
    func testCompleteMathFormulas() {
        let input = "Inline $a = b$ and display $$c = d$$ and TeX inline \\(e = f\\) and TeX display \\[g = h\\]"
        let (tokens, _) = tokenizer.tokenize(input)
        
        let formulaTokens = tokens.filter { $0.element == .formula }
        let formulaBlockTokens = tokens.filter { $0.element == .formulaBlock }
        
        XCTAssertEqual(formulaTokens.count, 2, "Should find two formula tokens")
        XCTAssertEqual(formulaBlockTokens.count, 2, "Should find two formula block tokens")
        
        XCTAssertEqual(formulaTokens[0].text, "$a = b$")
        XCTAssertEqual(formulaTokens[1].text, "\\(e = f\\)")
        XCTAssertEqual(formulaBlockTokens[0].text, "$$c = d$$")
        XCTAssertEqual(formulaBlockTokens[1].text, "\\[g = h\\]")
    }
    
    // MARK: - Unmatched Math Delimiters
    
    func testUnmatchedMathDelimiters() {
        let input = "Just a $ sign and some \\] closing"
        let (tokens, _) = tokenizer.tokenize(input)
        
        let textTokens = tokens.filter { $0.element == .text }
        let formulaTokens = tokens.filter { $0.element == .formula }
        let formulaBlockTokens = tokens.filter { $0.element == .formulaBlock }
        
        XCTAssertGreaterThan(textTokens.count, 0, "Should have text tokens")
        XCTAssertEqual(formulaTokens.count, 0, "Should not have formula tokens")
        XCTAssertEqual(formulaBlockTokens.count, 0, "Should not have formula block tokens")
    }
    
    func testUnmatchedDollarSigns() {
        let testCases = [
            "$",
            "$$$",
            "$$$$$",
            "$ unclosed",
            "unclosed $",
            "$$$ unclosed",
            "unclosed $$$"
        ]
        
        for input in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let formulaTokens = tokens.filter { $0.element == .formula }
            let formulaBlockTokens = tokens.filter { $0.element == .formulaBlock }
            
            if input == "$" {
                // Single dollar should be treated as text
                XCTAssertEqual(formulaTokens.count, 0, "Should not have formula tokens for '\(input)'")
                XCTAssertEqual(formulaBlockTokens.count, 0, "Should not have formula block tokens for '\(input)'")
            } else {
                // Other cases might have different behavior
                XCTAssertTrue(tokens.count > 1, "Should tokenize '\(input)'")
                XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF for '\(input)'")
            }
        }
    }
    
    func testUnmatchedTexDelimiters() {
        let testCases = [
            "\\(",
            "\\)",
            "\\[",
            "\\]",
            "\\( unclosed",
            "unclosed \\)",
            "\\[ unclosed",
            "unclosed \\]"
        ]
        
        for input in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let formulaTokens = tokens.filter { $0.element == .formula }
            let formulaBlockTokens = tokens.filter { $0.element == .formulaBlock }
            
            if input == "\\(" || input == "\\( unclosed" {
                // These should be treated as complete TeX inline math formulas
                XCTAssertEqual(formulaTokens.count, 1, "Should have one formula token for '\(input)'")
                XCTAssertEqual(formulaBlockTokens.count, 0, "Should not have formula block tokens for '\(input)'")
            } else if input == "\\[" || input == "\\[ unclosed" {
                // These should be treated as complete TeX display math formulas
                XCTAssertEqual(formulaTokens.count, 0, "Should not have formula tokens for '\(input)'")
                XCTAssertEqual(formulaBlockTokens.count, 1, "Should have one formula block token for '\(input)'")
            } else {
                // Other cases (\\), \\], unclosed \\), unclosed \\]) should not be treated as math formulas
                XCTAssertEqual(formulaTokens.count, 0, "Should not have formula tokens for '\(input)'")
                XCTAssertEqual(formulaBlockTokens.count, 0, "Should not have formula block tokens for '\(input)'")
            }
            
            XCTAssertTrue(tokens.count > 1, "Should tokenize '\(input)'")
            XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF for '\(input)'")
        }
    }
    
    // MARK: - Math Formula Performance Tests
    
    func testLargeMathFormulas() {
        let longFormula = "$" + String(repeating: "x + ", count: 1000) + "y$"
        let (tokens, _) = tokenizer.tokenize(longFormula)
        
        XCTAssertEqual(tokens.count, 2, "Should produce 2 tokens for long formula")
        XCTAssertEqual(tokens[0].element, .formula, "Should be formula token")
        XCTAssertEqual(tokens[1].element, .eof, "Should end with EOF")
    }
    
    func testManyMathFormulas() {
        let manyFormulas = Array(1...100).map { "$x_{\($0)}$" }.joined(separator: " ")
        let (tokens, _) = tokenizer.tokenize(manyFormulas)
        
        let formulaTokens = tokens.filter { $0.element == .formula }
        XCTAssertEqual(formulaTokens.count, 100, "Should find 100 formula tokens")
        XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF")
    }
    
    // MARK: - Math Formula with Markdown Context
    
    func testMathInMarkdownContext() {
        let testCases = [
            "# Heading with $math$",
            "## Heading with $$display$$",
            "**Bold** text with $formula$",
            "*Italic* text with $$block$$",
            "`Code` with $math$",
            "~~Strike~~ with $$display$$",
            "> Quote with $formula$",
            "- List item with $$block$$",
            "1. Ordered item with $math$",
            "| Table | with $formula$ |",
            "[Link](url) with $$display$$",
            "![Image](src) with $math$"
        ]
        
        for input in testCases {
            let (tokens, _) = tokenizer.tokenize(input)
            let mathTokens = tokens.filter { $0.element == .formula || $0.element == .formulaBlock }
            
            XCTAssertGreaterThan(mathTokens.count, 0, "Should find math tokens in: \(input)")
            XCTAssertEqual(tokens.last?.element, .eof, "Should end with EOF: \(input)")
        }
    }
}

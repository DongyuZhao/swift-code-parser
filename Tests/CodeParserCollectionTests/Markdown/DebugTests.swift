import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Debug Tests for Parsing Issues")
struct DebugTests {
    private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
    private let language: MarkdownLanguage

    init() {
        language = MarkdownLanguage()
        parser = CodeParser(language: language)
    }

    @Test("Debug simple fenced code block")
    func debugSimpleFencedCodeBlock() {
        let input = "```\n<\n >\n```"

        let result = parser.parse(input, language: language)

        // Verify results without debug output
        for error in result.errors {
            print("  Error: \(error.message)")
        }

        print("- Tokens: \(result.tokens.count)")
        for (i, token) in result.tokens.enumerated() {
            let escapedText = token.text
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            print("  [\(i)] \(token.element) = '\(escapedText)'")
        }

        print("\nAST:")
        result.root.debugPrint()

        // Print what we got vs what we expected

        // Don't fail the test, just debug
    }

    @Test("Debug simple ATX heading")
    func debugSimpleATXHeading() {
        let input = "# Hello World"

        let result = parser.parse(input, language: language)

        // Simple verification without debug output

        print("- AST:")
        result.root.debugPrint()

        let actualSig = sig(result.root)
        print("- Signature: \(actualSig)")

        print("=== END DEBUG ===\n")
    }

    @Test("Debug simple paragraph")
    func debugSimpleParagraph() {
        let input = "Hello world"
        print("\n=== DEBUG: Testing simple paragraph ===")
        print("Input: \(input.debugDescription)")

        let result = parser.parse(input, language: language)

        print("\nResult:")
        print("- Errors: \(result.errors.count)")
        for error in result.errors {
            print("  Error: \(error.message)")
        }

        print("- AST:")
        result.root.debugPrint()

        let actualSig = sig(result.root)
        print("- Signature: \(actualSig)")

        print("=== END DEBUG ===\n")
    }
}
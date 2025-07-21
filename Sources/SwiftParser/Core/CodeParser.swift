import Foundation

public final class CodeParser<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>
    private let tokenizer: CodeTokenizer<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
        self.tokenizer = CodeTokenizer(language: language)
    }

    public func parse(_ input: String, root: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeParseContext<Node, Token>) {
        let normalized = normalize(input)
        let tokens = tokenizer.tokenize(normalized)
        var context = CodeParseContext(current: root, tokens: tokens, state: language.state(of: normalized))

        while context.consuming < context.tokens.count {
            // Stop at EOF without recording an error
            if let token = context.tokens[context.consuming] as? MarkdownToken,
               token.element == .eof {
                break
            }

            var matched = false
            for node in language.nodes {
                if node.build(from: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                // If no builder matched, record an error and skip the token
                let token = context.tokens[context.consuming]
                let error = CodeError("Unrecognized token: \(token.element)", range: token.range)
                context.errors.append(error)
                context.consuming += 1
            }
        }

        return (root, context)
    }

    public func outdatedParse(_ input: String, root: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeParseContext<Node, Token>) {
        let normalized = normalize(input)
        let tokens = language.outdatedTokenizer?.tokenize(normalized) ?? []
        var context = CodeParseContext(current: root, tokens: tokens, state: language.state(of: normalized))

        while context.consuming < context.tokens.count {
            // Stop at EOF without recording an error
            if let token = context.tokens[context.consuming] as? MarkdownToken,
               token.element == .eof {
                break
            }

            var matched = false
            for node in language.nodes {
                if node.build(from: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                // If no builder matched, record an error and skip the token
                let token = context.tokens[context.consuming]
                let error = CodeError("Unrecognized token: \(token.element)", range: token.range)
                context.errors.append(error)
                context.consuming += 1
            }
        }

        return (root, context)
    }

    /// Normalizes input string to handle line ending inconsistencies and other common issues
    /// This ensures consistent behavior across different platforms and input sources
    private func normalize(_ raw: String) -> String {
        // Normalize line endings: Convert CRLF (\r\n) and CR (\r) to LF (\n)
        // This prevents issues with different line ending conventions
        return raw
            .replacingOccurrences(of: "\r\n", with: "\n")  // Windows CRLF -> Unix LF
            .replacingOccurrences(of: "\r", with: "\n")    // Classic Mac CR -> Unix LF
    }
}

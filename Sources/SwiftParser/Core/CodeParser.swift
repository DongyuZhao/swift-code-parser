import Foundation

public final class CodeParser<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
    }

    public func parse(_ input: String, root: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeContext<Node, Token>) {
        let normalized = normalize(input)
        let tokens = language.tokenizer.tokenize(normalized)
        var context = CodeContext(current: root, tokens: tokens, state: language.state(of: normalized))

        while context.consuming < context.tokens.count {
            var matched = false
            for builder in language.builders {
                if builder.build(from: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                // If no consumer matched, we have an unrecognized token
                let token = context.tokens[context.consuming]
                let error = CodeError("Unrecognized token: \(token.element)", range: token.range)
                context.errors.append(error)
                context.consuming += 1 // Skip the unrecognized token
            } else {
                break // Exit the loop if a consumer successfully processed tokens
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

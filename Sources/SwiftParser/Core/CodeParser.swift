import Foundation

public final class CodeParser<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
    }

    public func parse(_ input: String, root: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeContext<Node, Token>) {
        let normalized = normalize(input)
        let tokens = language.tokenizer.tokenize(normalized)
        var context = CodeContext(current: root, state: language.state(of: normalized))

        for token in tokens {
            var matched = false
            for consumer in language.consumers {
                if consumer.consume(token: token, context: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.element)", range: token.range))
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

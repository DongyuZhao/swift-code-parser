import Foundation

@available(*, deprecated, renamed: "CodeParser", message: "Use `CodeParser` instead.")
public final class CodeOutdatedParser<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
    }
    
    @available(*, deprecated, renamed: "parse", message: "Use `parse(_:)` instead.")
    public func parse(_ input: String, root: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeConstructContext<Node, Token>) {
        let normalized = normalize(input)
        let tokens = language.tokenizer.tokenize(normalized)
        var context = CodeConstructContext(current: root, tokens: tokens, state: language.state(of: normalized))

        while context.consuming < context.tokens.count {
            // Stop at EOF without recording an error
            if let token = context.tokens[context.consuming] as? MarkdownToken,
               token.element == .eof {
                break
            }

            var matched = false
            for builder in language.nodes {
                if builder.build(from: &context) {
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

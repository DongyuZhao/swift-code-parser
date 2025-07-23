/// Result returned from `CodeParser.parse` containing the AST, token stream and
/// any parsing errors.
public struct CodeParseResult<Node: CodeNodeElement, Token: CodeTokenElement> {
    public let root: CodeNode<Node>
    public let tokens: [any CodeToken<Token>]
    public let errors: [CodeError]

    /// Create a result object
    /// - Parameters:
    ///   - root: The constructed root node of the AST.
    ///   - tokens: Token stream produced while parsing.
    ///   - errors: Any errors that occurred during tokenization or AST
    ///     construction.
    public init(root: CodeNode<Node>, tokens: [any CodeToken<Token>], errors: [CodeError] = []) {
        self.root = root
        self.tokens = tokens
        self.errors = errors
    }
}

/// High level parser that orchestrates tokenization and AST construction.
///
/// `CodeParser` uses the provided `CodeLanguage` implementation to tokenize the
/// source text and then build an AST using the registered node builders.
public class CodeParser<Node: CodeNodeElement, Token: CodeTokenElement> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    private let tokenizer: CodeTokenizer<Token>
    private let constructor: CodeConstructor<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
        self.tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
        self.constructor = CodeConstructor(builders: language.nodes, state: language.state)
    }

    /// Parse a source string using the supplied language.
    ///
    /// This method first tokenizes the input and, if tokenization succeeds,
    /// constructs the AST using the language's node builders.
    /// - Parameter source: The raw text to parse.
    /// - Parameter language: The language definition to use for parsing.
    /// - Returns: A `CodeParseResult` containing the root node, tokens and any
    ///   errors encountered.
    public func parse(_ source: String, language: any CodeLanguage<Node, Token>) -> CodeParseResult<Node, Token> {
        let normalized = normalize(source)
        let root = language.root()
        let (tokens, errors) = tokenizer.tokenize(normalized)

        if !errors.isEmpty {
            return CodeParseResult(root: root, tokens: tokens, errors: errors)
        }

        let (parsed, failures) = constructor.parse(tokens, root: root)

        // Errors from the tokenization phase must be empty here
        return CodeParseResult(root: parsed, tokens: tokens, errors: failures)
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
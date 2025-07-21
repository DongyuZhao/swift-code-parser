public struct CodeParseResult<Node: CodeNodeElement, Token: CodeTokenElement> {
    public let root: CodeNode<Node>
    public let tokens: [any CodeToken<Token>]
    public let errors: [CodeError]

    public init(root: CodeNode<Node>, tokens: [any CodeToken<Token>], errors: [CodeError] = []) {
        self.root = root
        self.tokens = tokens
        self.errors = errors
    }
}

public class CodeParser<Node: CodeNodeElement, Token: CodeTokenElement> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    private let tokenizer: CodeTokenizer<Token>
    private let constructor: CodeConstructor<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
        self.tokenizer = CodeTokenizer(builders: language.tokens, state: language.state)
        self.constructor = CodeConstructor(builders: language.nodes, state: language.state)
    }

    public func parse(_ source: String, language: any CodeLanguage<Node, Token>) -> CodeParseResult<Node, Token> {
        let root = language.root()
        let (tokens, errors) = tokenizer.tokenize(source)

        if !errors.isEmpty {
            return CodeParseResult(root: root, tokens: tokens, errors: errors)
        }

        let (parsed, failures) = constructor.parse(tokens, root: root)

        // Errors from the tokenization phase must be empty here
        return CodeParseResult(root: parsed, tokens: tokens, errors: failures)
    }
}
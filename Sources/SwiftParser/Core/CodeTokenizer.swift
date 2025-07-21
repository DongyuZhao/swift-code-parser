import Foundation
public protocol CodeOutdatedTokenizer<Element> where Element: CodeTokenElement {
    associatedtype Element: CodeTokenElement
    func tokenize(_ input: String) -> [any CodeToken<Element>]
}

public class CodeTokenizer<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let language: any CodeLanguage<Node, Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.language = language
    }
    public func tokenize(_ input: String) -> [any CodeToken<Token>] {
        let context = CodeTokenContext<Token>(source: input, consuming: input.startIndex)
        let current = context.consuming
        while context.consuming < context.source.endIndex {
            for token in language.tokens {
                if token.build(from: context) {
                    break
                }
            }

            if current == context.consuming {
                // No token matched, record an error and skip one character
                context.errors.append(CodeError("Unrecognized character: \(context.source[context.consuming])", range: context.consuming..<context.consuming))
                break
            }
        }
        return context.tokens
    }
}

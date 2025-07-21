//
//  CodeTokenizer.swift
//  SwiftParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

public class CodeTokenizer<Token> where Token: CodeTokenElement {
    private let builders: [any CodeTokenBuilder<Token>]
    private var state: () -> (any CodeTokenState<Token>)?

    public init(builders: [any CodeTokenBuilder<Token>], state: @escaping () -> (any CodeTokenState<Token>)?) {
        self.builders = builders
        self.state = state
    }

    public func tokenize(_ input: String) -> ([any CodeToken<Token>], [CodeError]) {
        var context = CodeTokenContext<Token>(source: input, state: state())
        let current = context.consuming

        while context.consuming < context.source.endIndex {
            for token in builders {
                if token.build(from: &context) {
                    break
                }
            }

            if current == context.consuming {
                // No token matched, record an error and skip one character
                context.errors.append(CodeError("Unrecognized character: \(context.source[context.consuming])", range: context.consuming..<context.consuming))
                break
            }
        }

        return (context.tokens, context.errors)
    }
}

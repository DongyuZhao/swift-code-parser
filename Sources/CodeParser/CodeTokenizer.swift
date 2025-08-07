//
//  CodeTokenizer.swift
//  CodeParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

public class CodeTokenizer<Token> where Token: CodeTokenElement {
    private let builders: [any CodeTokenBuilder<Token>]
    private var state: () -> (any CodeTokenState<Token>)?
    private let eof: ((Range<String.Index>) -> (any CodeToken<Token>)?)?

    public init(
        builders: [any CodeTokenBuilder<Token>],
        state: @escaping () -> (any CodeTokenState<Token>)?,
        eof: ((Range<String.Index>) -> (any CodeToken<Token>)?)? = nil
    ) {
        self.builders = builders
        self.state = state
        self.eof = eof
    }

    public func tokenize(_ input: String) -> ([any CodeToken<Token>], [CodeError]) {
        var context = CodeTokenContext<Token>(source: input, state: state())

        while context.consuming < context.source.endIndex {
            let start = context.consuming
            var matched = false

            for builder in builders {
                if builder.build(from: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                // No token matched, record an error and skip one character
                let next = context.source.index(after: context.consuming)
                let range = context.consuming..<next
                context.errors.append(CodeError("Unrecognized character: \(context.source[context.consuming])", range: range))
                context.consuming = next
            }

            if start == context.consuming {
                // Ensure progress to avoid infinite loop
                context.consuming = context.source.index(after: context.consuming)
            }
        }

        // Append EOF token if provided by the language
        if let token = eof?(input.endIndex..<input.endIndex) {
            context.tokens.append(token)
        }

        return (context.tokens, context.errors)
    }
}

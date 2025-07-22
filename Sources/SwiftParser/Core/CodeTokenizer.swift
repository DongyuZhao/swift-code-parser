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

        // Automatically append EOF token for Markdown
        if Token.self == MarkdownTokenElement.self,
           let eof = MarkdownToken.eof(at: input.endIndex..<input.endIndex) as? any CodeToken<Token> {
            context.tokens.append(eof)
        }

        return (context.tokens, context.errors)
    }
}

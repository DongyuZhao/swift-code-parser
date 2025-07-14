import Foundation

public final class CodeParser {
    private var builders: [CodeElementBuilder]
    private let tokenizer: CodeTokenizer

    public init(tokenizer: CodeTokenizer, builders: [CodeElementBuilder] = []) {
        self.tokenizer = tokenizer
        self.builders = builders
    }

    public func register(builder: CodeElementBuilder) {
        builders.append(builder)
    }

    public func clearBuilders() {
        builders.removeAll()
    }

    public func parse(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        let tokens = tokenizer.tokenize(input)
        var context = CodeContext(tokens: tokens, index: 0, currentNode: rootNode, errors: [], input: input)
        while context.index < context.tokens.count {
            let token = context.tokens[context.index]
            if token.kindDescription == "eof" {
                break
            }
            var matched = false
            for builder in builders {
                if builder.accept(context: context, token: token) {
                    builder.build(context: &context)
                    matched = true
                    break
                }
            }
            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.kindDescription)", range: token.range))
                context.index += 1
            }
        }
        return (rootNode, context)
    }

    public func update(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        // Simple implementation: reparse everything
        return parse(input, rootNode: rootNode)
    }
}

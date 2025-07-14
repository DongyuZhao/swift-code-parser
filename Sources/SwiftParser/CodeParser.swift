import Foundation

public final class CodeParser {
    private var builders: [CodeElementBuilder]
    private let tokenizer: CodeTokenizer
    private var expressionBuilder: CodeExpressionBuilder?

    public init(tokenizer: CodeTokenizer, builders: [CodeElementBuilder] = [], expressionBuilder: CodeExpressionBuilder? = nil) {
        self.tokenizer = tokenizer
        self.builders = builders
        self.expressionBuilder = expressionBuilder
    }

    public func register(builder: CodeElementBuilder) {
        builders.append(builder)
    }

    public func clearBuilders() {
        builders.removeAll()
    }

    public func register(expressionBuilder: CodeExpressionBuilder) {
        self.expressionBuilder = expressionBuilder
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
            if !matched, let expr = expressionBuilder, expr.accept(context: context, token: token) {
                if let node = expr.parse(context: &context) {
                    context.currentNode.addChild(node)
                }
                matched = true
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

    public func parseExpression(context: inout CodeContext, minBP: Int = 0) -> CodeNode? {
        guard let expr = expressionBuilder else { return nil }
        return expr.parse(context: &context, minBP: minBP)
    }
}

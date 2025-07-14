import Foundation

public final class CodeParser {
    private var builders: [CodeElementBuilder]
    private let tokenizer: CodeTokenizer
    private var expressionBuilders: [CodeExpressionBuilder]

    // State for incremental parsing
    private var lastContext: CodeContext?
    private var snapshots: [Int: CodeContext.Snapshot] = [:]
    private var lastTokens: [any CodeToken] = []

    public init(tokenizer: CodeTokenizer, builders: [CodeElementBuilder] = [], expressionBuilders: [CodeExpressionBuilder] = []) {
        self.tokenizer = tokenizer
        self.builders = builders
        self.expressionBuilders = expressionBuilders
    }

    public func register(builder: CodeElementBuilder) {
        builders.append(builder)
    }

    public func unregister(builder: CodeElementBuilder) {
        if let target = builder as? AnyObject {
            if let index = builders.firstIndex(where: { ($0 as? AnyObject) === target }) {
                builders.remove(at: index)
            }
        }
    }

    public func clearBuilders() {
        builders.removeAll()
    }

    public func register(expressionBuilder: CodeExpressionBuilder) {
        expressionBuilders.append(expressionBuilder)
    }

    public func unregister(expressionBuilder: CodeExpressionBuilder) {
        if let target = expressionBuilder as? AnyObject {
            if let index = expressionBuilders.firstIndex(where: { ($0 as? AnyObject) === target }) {
                expressionBuilders.remove(at: index)
            }
        }
    }

    public func clearExpressionBuilders() {
        expressionBuilders.removeAll()
    }

    public func parse(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        let tokens = tokenizer.tokenize(input)
        var context = CodeContext(tokens: tokens, index: 0, currentNode: rootNode, errors: [], input: input, linkReferences: [:])

        snapshots = [:]
        lastTokens = tokens

        while context.index < context.tokens.count {
            snapshots[context.index] = context.snapshot()
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
                for expr in expressionBuilders {
                    if expr.accept(context: context, token: token) {
                        if let node = expr.parse(context: &context) {
                            context.currentNode.addChild(node)
                        }
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.kindDescription)", range: token.range))
                context.index += 1
            }
        }
        snapshots[context.index] = context.snapshot()
        lastContext = context
        return (rootNode, context)
    }

    public func update(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        guard var context = lastContext else {
            return parse(input, rootNode: rootNode)
        }

        let newTokens = tokenizer.tokenize(input)

        var diffIndex = 0
        while diffIndex < min(lastTokens.count, newTokens.count) {
            if !tokenEqual(lastTokens[diffIndex], newTokens[diffIndex]) {
                break
            }
            diffIndex += 1
        }

        var restoreIndex = diffIndex
        while restoreIndex >= 0 && snapshots[restoreIndex] == nil {
            restoreIndex -= 1
        }
        if let snap = snapshots[restoreIndex] {
            context.restore(snap)
        }

        context.tokens = newTokens
        context.index = restoreIndex

        snapshots = snapshots.filter { $0.key <= restoreIndex }
        lastTokens = newTokens

        while context.index < context.tokens.count {
            snapshots[context.index] = context.snapshot()
            let token = context.tokens[context.index]
            if token.kindDescription == "eof" { break }
            var matched = false
            for builder in builders {
                if builder.accept(context: context, token: token) {
                    builder.build(context: &context)
                    matched = true
                    break
                }
            }
            if !matched {
                for expr in expressionBuilders {
                    if expr.accept(context: context, token: token) {
                        if let node = expr.parse(context: &context) {
                            context.currentNode.addChild(node)
                        }
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.kindDescription)", range: token.range))
                context.index += 1
            }
        }
        snapshots[context.index] = context.snapshot()
        lastContext = context
        return (rootNode, context)
    }

    private func tokenEqual(_ a: any CodeToken, _ b: any CodeToken) -> Bool {
        return a.kindDescription == b.kindDescription && a.text == b.text
    }

    public func parseExpression(context: inout CodeContext, minBP: Int = 0) -> CodeNode? {
        guard context.index < context.tokens.count else { return nil }
        let token = context.tokens[context.index]
        for expr in expressionBuilders {
            if expr.accept(context: context, token: token) {
                return expr.parse(context: &context, minBP: minBP)
            }
        }
        return nil
    }
}

import Foundation

public final class CodeParser {
    private var consumers: [CodeTokenConsumer]
    private let tokenizer: CodeTokenizer

    // State for incremental parsing
    private var lastContext: CodeContext?
    private var snapshots: [Int: CodeContext.Snapshot] = [:]
    private var lastTokens: [any CodeToken] = []

    public init(tokenizer: CodeTokenizer, consumers: [CodeTokenConsumer] = []) {
        self.tokenizer = tokenizer
        self.consumers = consumers
    }

    public func register(consumer: CodeTokenConsumer) {
        consumers.append(consumer)
    }

    public func unregister(consumer: CodeTokenConsumer) {
        if let target = consumer as? AnyObject {
            if let index = consumers.firstIndex(where: { ($0 as? AnyObject) === target }) {
                consumers.remove(at: index)
            }
        }
    }

    public func clearConsumers() {
        consumers.removeAll()
    }


    public func parse(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        let tokens = tokenizer.tokenize(input)
        var context = CodeContext(tokens: tokens, index: 0, currentNode: rootNode, errors: [], input: input, linkReferences: [:])

        snapshots = [:]
        lastTokens = tokens

        // Infinite loop protection: track index progression
        var lastIndex = -1

        while context.index < context.tokens.count {
            // Infinite loop detection - if index hasn't advanced, terminate parsing immediately
            if context.index == lastIndex {
                context.errors.append(CodeError("Infinite loop detected: parser stuck at token index \(context.index). Terminating parse to prevent hang.", range: context.tokens[context.index].range))
                break
            }
            lastIndex = context.index
            
            snapshots[context.index] = context.snapshot()
            let token = context.tokens[context.index]
            if token.kindDescription == "eof" {
                break
            }
            var matched = false
            for consumer in consumers {
                if consumer.consume(context: &context, token: token) {
                    matched = true
                    break
                }
            }
            // No expression builders remaining
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

        // Infinite loop protection for update method
        var lastIndex = -1

        while context.index < context.tokens.count {
            // Infinite loop detection - if index hasn't advanced, terminate parsing immediately
            if context.index == lastIndex {
                context.errors.append(CodeError("Infinite loop detected in update: parser stuck at token index \(context.index). Terminating parse to prevent hang.", range: context.tokens[context.index].range))
                break
            }
            lastIndex = context.index
            
            snapshots[context.index] = context.snapshot()
            let token = context.tokens[context.index]
            if token.kindDescription == "eof" { break }
            var matched = false
            for consumer in consumers {
                if consumer.consume(context: &context, token: token) {
                    matched = true
                    break
                }
            }
            // No expression builders remaining
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

}

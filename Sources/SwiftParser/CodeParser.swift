import Foundation

public final class CodeParser {
    private var consumers: [CodeTokenConsumer]
    private let tokenizer: CodeTokenizer

    // Registered state is now reset for each parse run

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
        var context = CodeContext(tokens: tokens, index: 0, currentNode: rootNode, errors: [], input: input)

        // Infinite loop protection: track index progression
        var lastIndex = -1

        while context.index < context.tokens.count {
            // Infinite loop detection - if index hasn't advanced, terminate parsing immediately
            if context.index == lastIndex {
                context.errors.append(CodeError("Infinite loop detected: parser stuck at token index \(context.index). Terminating parse to prevent hang.", range: context.tokens[context.index].range))
                break
            }
            lastIndex = context.index
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
        return (rootNode, context)
    }

}

//
//  CodeParser.swift
//  SwiftParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

public class CodeConstructor<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    private let builders: [any CodeNodeBuilder<Node, Token>]
    private var state: () -> (any CodeConstructState<Node, Token>)?
    
    public init(builders: [any CodeNodeBuilder<Node, Token>], state: @escaping () -> (any CodeConstructState<Node, Token>)?) {
        self.builders = builders
        self.state = state
    }
    
    public func parse(_ tokens: [any CodeToken<Token>], root: CodeNode<Node>) -> (CodeNode<Node>, [CodeError]) {
        var context = CodeConstructContext(current: root, tokens: tokens, state: state())

        while context.consuming < context.tokens.count {
            // Stop at EOF without recording an error
            if let token = context.tokens[context.consuming] as? MarkdownToken,
               token.element == .eof {
                break
            }

            var matched = false
            for node in builders {
                if node.build(from: &context) {
                    matched = true
                    break
                }
            }

            if !matched {
                // If no builder matched, record an error and skip the token
                let token = context.tokens[context.consuming]
                let error = CodeError("Unrecognized token: \(token.element)", range: token.range)
                context.errors.append(error)
                context.consuming += 1
            }
        }

        return (root, context.errors)
    }
}
    

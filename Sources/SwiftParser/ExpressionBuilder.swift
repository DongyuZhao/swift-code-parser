import Foundation

public protocol CodeExpressionBuilder: CodeTokenConsumer {
    func isPrefix(token: any CodeToken) -> Bool
    func prefix(context: inout CodeContext, token: any CodeToken) -> CodeNode?
    func infixBindingPower(of token: any CodeToken) -> (left: Int, right: Int)?
    func infix(context: inout CodeContext, left: CodeNode, token: any CodeToken, right: CodeNode) -> CodeNode
}

public extension CodeExpressionBuilder {
    func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard isPrefix(token: token) else { return false }
        if let node = parse(context: &context) {
            context.currentNode.addChild(node)
        }
        return true
    }

    func parse(context: inout CodeContext, minBP: Int = 0) -> CodeNode? {
        guard context.index < context.tokens.count else { return nil }
        let first = context.tokens[context.index]
        guard isPrefix(token: first) else { return nil }
        context.index += 1
        guard var left = prefix(context: &context, token: first) else { return nil }
        while context.index < context.tokens.count {
            let opToken = context.tokens[context.index]
            guard let bp = infixBindingPower(of: opToken), bp.left >= minBP else { break }
            context.index += 1
            let right = parse(context: &context, minBP: bp.right) ?? CodeNode(type: left.type, value: "")
            left = infix(context: &context, left: left, token: opToken, right: right)
        }
        return left
    }
}

import Foundation
import SwiftParser

/// Recursive descent parser used by Formula node builders.
struct FormulaParser {
    static func parseExpression(_ context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> FormulaNodeBase? {
        guard let left = parseTerm(&context) else { return nil }
        var node = left
        while context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? FormulaToken,
              token.element == .plus || token.element == .minus || token.element == .equals {
            context.consuming += 1
            let op = opFromToken(token.element)
            guard let right = parseTerm(&context) else { break }
            node = BinaryOperationNode(op: op, left: node, right: right)
        }
        return node
    }

    private static func parseTerm(_ context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> FormulaNodeBase? {
        guard let left = parseFactor(&context) else { return nil }
        var node = left
        while context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? FormulaToken,
              token.element == .star || token.element == .slash {
            context.consuming += 1
            let op = opFromToken(token.element)
            guard let right = parseFactor(&context) else { break }
            node = BinaryOperationNode(op: op, left: node, right: right)
        }
        return node
    }

    private static func parseFactor(_ context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> FormulaNodeBase? {
        // handle unary operators
        if context.consuming < context.tokens.count,
           let tok = context.tokens[context.consuming] as? FormulaToken,
           tok.element == .plus || tok.element == .minus {
            context.consuming += 1
            guard let operand = parseFactor(&context) else { return nil }
            let op = unaryOpFromToken(tok.element)
            return UnaryOperationNode(op: op, operand: operand)
        }

        guard var node = parseAtom(&context) else { return nil }
        while context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? FormulaToken,
              token.element == .caret || token.element == .underscore {
            context.consuming += 1
            let op = opFromToken(token.element)
            guard let right = parseAtom(&context) else { break }
            node = BinaryOperationNode(op: op, left: node, right: right)
        }
        return node
    }

    private static func parseAtom(_ context: inout CodeConstructContext<FormulaNodeElement, FormulaTokenElement>) -> FormulaNodeBase? {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? FormulaToken else { return nil }
        switch token.element {
        case .number:
            context.consuming += 1
            return NumberNode(value: token.text)
        case .identifier:
            context.consuming += 1
            return IdentifierNode(name: token.text)
        case .command:
            context.consuming += 1
            var args: [FormulaNodeBase] = []
            while context.consuming < context.tokens.count,
                  let open = context.tokens[context.consuming] as? FormulaToken,
                  open.element == .lbrace {
                context.consuming += 1
                if let arg = parseExpression(&context) { args.append(arg) }
                if context.consuming < context.tokens.count,
                   let close = context.tokens[context.consuming] as? FormulaToken,
                   close.element == .rbrace {
                    context.consuming += 1
                }
            }
            return CommandNode(name: token.text, arguments: args)
        case .lparen:
            context.consuming += 1
            let expr = parseExpression(&context)
            if context.consuming < context.tokens.count,
               let close = context.tokens[context.consuming] as? FormulaToken,
               close.element == .rparen {
                context.consuming += 1
            }
            if let expr = expr { return GroupNode(children: [expr]) } else { return nil }
        case .lbrace:
            context.consuming += 1
            let expr = parseExpression(&context)
            if context.consuming < context.tokens.count,
               let close = context.tokens[context.consuming] as? FormulaToken,
               close.element == .rbrace {
                context.consuming += 1
            }
            if let expr = expr { return GroupNode(children: [expr]) } else { return nil }
        default:
            return nil
        }
    }

    private static func opFromToken(_ element: FormulaTokenElement) -> BinaryOperator {
        switch element {
        case .plus: return .plus
        case .minus: return .minus
        case .star: return .times
        case .slash: return .divide
        case .caret: return .caret
        case .underscore: return .underscore
        case .equals: return .equals
        default: return .plus
        }
    }

    private static func unaryOpFromToken(_ element: FormulaTokenElement) -> UnaryOperator {
        switch element {
        case .plus: return .plus
        case .minus: return .minus
        default: return .plus
        }
    }
}

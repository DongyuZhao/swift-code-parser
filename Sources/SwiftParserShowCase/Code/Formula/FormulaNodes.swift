import Foundation
import SwiftParser

public class FormulaNodeBase: CodeNode<FormulaNodeElement> {
    public override init(element: FormulaNodeElement) {
        super.init(element: element)
    }

    public func append(_ child: FormulaNodeBase) {
        super.append(child)
    }
}

public class FormulaDocumentNode: FormulaNodeBase {
    public init() {
        super.init(element: .document)
    }
}

public class NumberNode: FormulaNodeBase {
    public var value: String
    public init(value: String) {
        self.value = value
        super.init(element: .number)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(value)
    }
}

public class IdentifierNode: FormulaNodeBase {
    public var name: String
    public init(name: String) {
        self.name = name
        super.init(element: .identifier)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(name)
    }
}

public class CommandNode: FormulaNodeBase {
    public var name: String
    public var arguments: [FormulaNodeBase]

    public init(name: String, arguments: [FormulaNodeBase]) {
        self.name = name
        self.arguments = arguments
        super.init(element: .command)
        for arg in arguments { append(arg) }
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(name)
    }
}

public enum BinaryOperator: String {
    case plus = "+"
    case minus = "-"
    case times = "*"
    case divide = "/"
    case caret = "^"
    case underscore = "_"
    case equals = "="
}

public enum UnaryOperator: String {
    case plus = "+"
    case minus = "-"
}

public class BinaryOperationNode: FormulaNodeBase {
    public var op: BinaryOperator
    public var left: FormulaNodeBase
    public var right: FormulaNodeBase

    public init(op: BinaryOperator, left: FormulaNodeBase, right: FormulaNodeBase) {
        self.op = op
        self.left = left
        self.right = right
        super.init(element: .binaryOperation)
        append(left)
        append(right)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(op.rawValue)
    }
}

public class UnaryOperationNode: FormulaNodeBase {
    public var op: UnaryOperator
    public var operand: FormulaNodeBase

    public init(op: UnaryOperator, operand: FormulaNodeBase) {
        self.op = op
        self.operand = operand
        super.init(element: .unaryOperation)
        append(operand)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(op.rawValue)
    }
}

public class GroupNode: FormulaNodeBase {
    public init(children: [FormulaNodeBase]) {
        super.init(element: .group)
        for child in children { append(child) }
    }
}

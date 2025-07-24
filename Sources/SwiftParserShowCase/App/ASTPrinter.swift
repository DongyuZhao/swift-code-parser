import SwiftParser

struct ASTPrinter {
    static func print(node: CodeNode<MarkdownNodeElement>, indent: Int = 0) -> String {
        var lines: [String] = []
        func recurse(_ node: CodeNode<MarkdownNodeElement>, _ depth: Int) {
            let prefix = String(repeating: "  ", count: depth)
            lines.append("\(prefix)\(node.element.rawValue)")
            for child in node.children {
                recurse(child, depth + 1)
            }
        }
        recurse(node, indent)
        return lines.joined(separator: "\n")
    }
}

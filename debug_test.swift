import CodeParserCollection
import CodeParserCore

let language = MarkdownLanguage()
let parser = CodeParser(language: language)

let input = """
aaa
bbb
"""

let result = parser.parse(input, language: language)
print("Errors: \(result.errors)")
print("Root: \(result.root)")

func traverse(_ node: CodeNode<MarkdownNodeElement>, level: Int = 0) {
    let indent = String(repeating: "  ", count: level)
    print("\(indent)\(type(of: node)): \(node.element)")
    if let textNode = node as? TextNode {
        print("\(indent)  content: '\(textNode.content)'")
    }
    if let contentNode = node as? ContentNode {
        print("\(indent)  tokens: \(contentNode.tokens.map { "\($0.element):\($0.text)" })")
    }
    for child in node.children {
        traverse(child, level: level + 1)
    }
}

traverse(result.root)
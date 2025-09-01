import CodeParserCollection

let processor = MarkdownInlineProcessor()
let input = "foo *bar* \\*baz\\*"
print("Input: \(input)")

let result = processor.processInlineContent(input)
print("Result count: \(result.count)")

for (i, node) in result.enumerated() {
  print("Node \(i): \(type(of: node)) - \(node.element)")
  if let textNode = node as? MarkdownText {
    print("  Content: '\(textNode.content)'")
  }
}
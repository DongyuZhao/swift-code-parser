import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

struct MarkdownTestHarness {
  let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }
}

// Generic AST search helper reused by suites
func findNodes<T: CodeNode<MarkdownNodeElement>>(in root: CodeNode<MarkdownNodeElement>, ofType type: T.Type) -> [T] {
  var result: [T] = []
  func traverse(_ node: CodeNode<MarkdownNodeElement>) {
    if let typed = node as? T { result.append(typed) }
    for child in node.children { traverse(child) }
  }
  traverse(root)
  return result
}

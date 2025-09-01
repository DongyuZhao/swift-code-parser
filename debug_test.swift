#!/usr/bin/env swift

import Foundation

// Add paths to find the modules
import CodeParserCore
import CodeParserCollection

let language = MarkdownLanguage()
let parser = CodeParser(language: language)

// Test simple nested list case
let input = """
- a
  - b
"""

let result = parser.parse(input, language: language)

func sig(_ node: CodeNode<MarkdownNodeElement>) -> String {
  return node.signature()
}

print("Input:")
print(input)
print("\nActual output:")
print(sig(result.root))
print("\nExpected:")
print("document[unordered_list(level:1)[list_item[paragraph[text(\"a\")],unordered_list(level:2)[list_item[paragraph[text(\"b\")]]]]]]")
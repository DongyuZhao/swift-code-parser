#!/usr/bin/env swift

import Foundation

// Add paths to find the modules
import CodeParserCore
import CodeParserCollection

let language = MarkdownLanguage()
let parser = CodeParser(language: language)

// Test the specific failing case
let input = """
- foo
  - bar
    - baz

      bim
"""

print("Testing input:")
print(input)
print("\nParsing...")

let result = parser.parse(input, language: language)

func sig(_ node: CodeNode<MarkdownNodeElement>) -> String {
  return node.signature()
}

print("Result:")
print(sig(result.root))

print("\nExpected:")
print(#"document[unordered_list(level:1)[list_item[paragraph[text("foo")],unordered_list(level:2)[list_item[paragraph[text("bar")],unordered_list(level:3)[list_item[paragraph[text("baz")],paragraph[text("bim")]]]]]]]]"#)
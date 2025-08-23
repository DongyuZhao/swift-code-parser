#!/usr/bin/env swift

import Foundation

// Add paths to find the modules
import CodeParserCore
import CodeParserCollection

let language = MarkdownLanguage()
let parser = CodeParser(language: language)

print("Testing input: \"--\\n**\\n__\"")
let input = "--\n**\n__"

do {
    let result = parser.parse(input, language: language)
    print("Parse succeeded")
} catch {
    print("Parse failed with error: \(error)")
}
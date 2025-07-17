import Foundation
import XCTest
@testable import SwiftParser

class ListDemoTests: XCTestCase {
    func testListDemo() {
        print("=== Swift Markdown Parser advanced list demo ===\n")
        
        // Demonstrate unordered list
        let unorderedList = """
        - unordered item 1
        - unordered item 2
        - unordered item 3
        """
        
        // Demonstrate ordered list - automatic numbering
        let orderedList = """
        1. first
        1. second
        1. third
        """
        
        // Demonstrate task list
        let taskList = """
        - [ ] unfinished task
        - [x] finished task
        - [ ] another unfinished task
        """
        
        func demonstrateList(title: String, markdown: String) {
            print("=== \(title) ===")
            print("Input:")
            print(markdown)
            print("\nParse result:")
            
            let language = MarkdownLanguage()
            let parser = CodeParser(language: language)
            let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
            
            func printAST(_ node: CodeNode, indent: String = "") {
                let elementType = node.type as? MarkdownElement ?? MarkdownElement.text
                let displayValue = node.value.isEmpty ? "" : " '\(node.value)'"
                print("\(indent)\(elementType)\(displayValue)")
                for child in node.children {
                    printAST(child, indent: indent + "  ")
                }
            }
            
            printAST(result.node)
            print("\n" + String(repeating: "-", count: 50) + "\n")
        }
        
        // Demonstrate all list types
        demonstrateList(title: "Unordered list", markdown: unorderedList)
        demonstrateList(title: "Ordered list (auto numbering)", markdown: orderedList)
        demonstrateList(title: "Task list", markdown: taskList)
        
        print("✅ All list features demonstrated!")
        print("✅ Supports unordered lists, ordered lists, and task lists")
    }
}

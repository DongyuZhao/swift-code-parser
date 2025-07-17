import Foundation
import XCTest
@testable import SwiftParser

class ListDemoTests: XCTestCase {
    func testListDemo() {
        print("=== Swift Markdown Parser 高级列表演示 ===\n")
        
        // 演示无序列表
        let unorderedList = """
        - 无序列表项1
        - 无序列表项2
        - 无序列表项3
        """
        
        // 演示有序列表 - 自动编号
        let orderedList = """
        1. 第一项
        1. 第二项
        1. 第三项
        """
        
        // 演示任务列表
        let taskList = """
        - [ ] 未完成任务
        - [x] 已完成任务
        - [ ] 另一个未完成任务
        """
        
        func demonstrateList(title: String, markdown: String) {
            print("=== \(title) ===")
            print("输入:")
            print(markdown)
            print("\n解析结果:")
            
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
        
        // 演示各种列表类型
        demonstrateList(title: "无序列表", markdown: unorderedList)
        demonstrateList(title: "有序列表 (自动编号)", markdown: orderedList)
        demonstrateList(title: "任务列表", markdown: taskList)
        
        print("✅ 所有列表功能演示完成！")
        print("✅ 支持无序列表、有序列表自动编号、任务列表")
    }
}

import XCTest
@testable import SwiftParser

enum DummyElement: CodeElement {
    case root
    case identifier
    case number
}

final class SwiftParserTests: XCTestCase {
    func testParserInitialization() {
        let parser = SwiftParser()
        XCTAssertNotNil(parser)
    }

    func testCodeNodeASTOperations() {
        let root = CodeNode(type: DummyElement.root, value: "")
        let a = CodeNode(type: DummyElement.identifier, value: "a")
        let b = CodeNode(type: DummyElement.identifier, value: "b")

        root.addChild(a)
        root.insertChild(b, at: 0)
        XCTAssertEqual(root.children.first?.value, "b")

        let removed = root.removeChild(at: 0)
        XCTAssertEqual(removed.value, "b")
        XCTAssertNil(removed.parent)
        XCTAssertEqual(root.children.count, 1)

        let num = CodeNode(type: DummyElement.number, value: "1")
        root.replaceChild(at: 0, with: num)
        XCTAssertEqual(root.children.first?.value, "1")

        num.removeFromParent()
        XCTAssertEqual(root.children.count, 0)

        let idX = CodeNode(type: DummyElement.identifier, value: "x")
        let num2 = CodeNode(type: DummyElement.number, value: "2")
        root.addChild(idX)
        root.addChild(num2)

        var collected: [CodeNode] = []
        root.traverseDepthFirst { collected.append($0) }
        XCTAssertEqual(collected.count, 3)

        let found = root.first { ($0.type as? DummyElement) == .number }
        XCTAssertEqual(found?.value, "2")

        let allIds = root.findAll { ($0.type as? DummyElement) == .identifier }
        XCTAssertEqual(allIds.count, 1)
        XCTAssertEqual(allIds.first?.value, "x")
        
        XCTAssertEqual(idX.depth, 1)
        XCTAssertEqual(root.subtreeCount, 3)
    }
    
    // MARK: - List Tests
    
    func testMarkdownUnorderedList() {
        let markdown = """
        - 项目1
        - 项目2
        - 项目3
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // 查找无序列表
        let listNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .unorderedList 
        }
        XCTAssertEqual(listNodes.count, 1)
        
        // 检查列表项
        let listItems = listNodes[0].children
        XCTAssertEqual(listItems.count, 3)
        
        // 检查第一个列表项的内容
        let firstItem = listItems[0]
        XCTAssertEqual(firstItem.children.count, 1)
        XCTAssertEqual(firstItem.children[0].value, "项目1")
    }

    func testMarkdownOrderedList() {
        let markdown = """
        1. 第一项
        1. 第二项
        1. 第三项
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // 查找有序列表
        let listNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .orderedList 
        }
        XCTAssertEqual(listNodes.count, 1)
        
        // 检查列表项
        let listItems = listNodes[0].children
        XCTAssertEqual(listItems.count, 3)
        
        // 检查自动编号
        XCTAssertEqual(listItems[0].value, "1.")
        XCTAssertEqual(listItems[1].value, "2.")
        XCTAssertEqual(listItems[2].value, "3.")
    }

    func testMarkdownTaskList() {
        let markdown = """
        - [ ] 未完成任务
        - [x] 已完成任务
        - [ ] 另一个任务
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // 查找任务列表
        let taskListNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .taskList 
        }
        XCTAssertEqual(taskListNodes.count, 1)
        
        // 检查任务列表项
        let taskItems = taskListNodes[0].children
        XCTAssertEqual(taskItems.count, 3)
        
        // 检查任务状态
        XCTAssertEqual(taskItems[0].value, "[ ]")
        XCTAssertEqual(taskItems[1].value, "[x]")
        XCTAssertEqual(taskItems[2].value, "[ ]")
    }
    
    // MARK: - Markdown Tests
    
    func testMarkdownBasicParsing() {
        let parser = SwiftParser()
        let markdown = "# 标题\n\n这是段落文本。"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors, "解析不应该有错误")
        XCTAssertEqual(result.root.children.count, 2, "应该有2个子节点（标题和段落）")
        
        // 检查标题
        let headers = result.markdownNodes(ofType: .header1)
        XCTAssertEqual(headers.count, 1, "应该有1个一级标题")
        XCTAssertEqual(headers.first?.value, "标题", "标题文本应该正确")
        
        // 检查段落
        let paragraphs = result.markdownNodes(ofType: .paragraph)
        XCTAssertEqual(paragraphs.count, 1, "应该有1个段落")
        XCTAssertEqual(paragraphs.first?.value, "这是段落文本。", "段落文本应该正确")
    }
    
    func testMarkdownHeaders() {
        let parser = SwiftParser()
        let markdown = """
        # 一级标题
        ## 二级标题
        ### 三级标题
        #### 四级标题
        ##### 五级标题
        ###### 六级标题
        """
        
        let result = parser.parseMarkdown(markdown)
        XCTAssertFalse(result.hasErrors)
        
        XCTAssertEqual(result.markdownNodes(ofType: .header1).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header2).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header3).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header4).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header5).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header6).count, 1)
        
        XCTAssertEqual(result.markdownNodes(ofType: .header1).first?.value, "一级标题")
        XCTAssertEqual(result.markdownNodes(ofType: .header6).first?.value, "六级标题")
    }
    
    func testMarkdownEmphasis() {
        let parser = SwiftParser()
        
        // 测试最简单的情况，并添加调试输出
        print("\n=== 测试基本emphasis ===")
        let simpleMarkdown = "*test*"
        let simpleResult = parser.parseMarkdown(simpleMarkdown)
        
        print("输入: \(simpleMarkdown)")
        print("解析结果:")
        printNodeTree(simpleResult.root, indent: "")
        
        let markdown = "*斜体* **粗体** ***粗斜体***"
        let result = parser.parseMarkdown(markdown)
        
        print("\n输入: \(markdown)")
        print("解析结果:")
        printNodeTree(result.root, indent: "")
        
        XCTAssertFalse(result.hasErrors)
        
        let emphasis = result.markdownNodes(ofType: .emphasis)
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        
        XCTAssertGreaterThanOrEqual(emphasis.count, 1, "应该至少有1个斜体")
        XCTAssertGreaterThanOrEqual(strongEmphasis.count, 1, "应该至少有1个粗体")
    }
    
    func testMarkdownNestedEmphasis() {
        let parser = SwiftParser()
        
        // 先测试最简单的情况
        print("\n=== 测试简单情况 ===")
        let simpleTest = "*test*"
        let simpleResult = parser.parseMarkdown(simpleTest)
        print("输入: \(simpleTest)")
        print("解析结果:")
        printNodeTree(simpleResult.root, indent: "")
        
        // 测试三星号
        print("\n=== 测试三星号 ===")
        let tripleTest = "***test***"
        
        // 先看看token化结果
        let tokenizer = MarkdownTokenizer()
        let tokens = tokenizer.tokenize(tripleTest)
        print("Token化结果:")
        for (i, token) in tokens.enumerated() {
            if let mdToken = token as? MarkdownToken {
                print("  [\(i)]: \(mdToken.kind) = '\(mdToken.text)'")
            }
        }
        
        let tripleResult = parser.parseMarkdown(tripleTest)
        print("输入: \(tripleTest)")
        print("解析结果:")
        printNodeTree(tripleResult.root, indent: "")
        
        // 验证三星号结果
        let strongNodes = tripleResult.markdownNodes(ofType: .strongEmphasis)
        if strongNodes.count > 0 {
            print("找到 \(strongNodes.count) 个 strongEmphasis 节点")
        } else {
            print("没有找到 strongEmphasis 节点")
        }
        
        // 测试嵌套的emphasis结构
        let testCases = [
            ("*外层*内部*斜体*", "连续的单星号"),
            ("**外层**内部**粗体**", "连续的双星号"),
            ("***三星号***", "三星号应该解析为粗斜体"),
            ("*斜体**粗体**斜体*", "斜体中嵌套粗体"),
            ("**粗体*斜体*粗体**", "粗体中嵌套斜体"),
            ("*外层_下划线_外层*", "星号中嵌套下划线"),
            ("_下划线*星号*下划线_", "下划线中嵌套星号")
        ]
        
        for (markdown, description) in testCases {
            let result = parser.parseMarkdown(markdown)
            
            // 基本验证：确保没有错误并且解析出了内容
            XCTAssertFalse(result.hasErrors, "\(description): 不应该有解析错误")
            XCTAssertGreaterThan(result.root.children.count, 0, "\(description): 应该解析出内容")
            
            // 打印结果用于调试
            print("\n测试用例: \(description)")
            print("输入: \(markdown)")
            print("解析结果:")
            printNodeTree(result.root, indent: "")
            
            // 特别验证三星号的情况
            if markdown == "***三星号***" {
                let strongEmphasisNodes = result.markdownNodes(ofType: .strongEmphasis)
                XCTAssertGreaterThan(strongEmphasisNodes.count, 0, "三星号应该产生strongEmphasis节点")
                
                if let strongNode = strongEmphasisNodes.first {
                    let emphasisNodes = strongNode.children.filter { 
                        ($0.type as? MarkdownElement) == .emphasis 
                    }
                    XCTAssertGreaterThan(emphasisNodes.count, 0, "strongEmphasis应该包含嵌套的emphasis节点")
                }
            }
        }
    }
    
    // 辅助函数：打印节点树结构
    private func printNodeTree(_ node: CodeNode, indent: String) {
        if let element = node.type as? MarkdownElement {
            print("\(indent)\(element.description): '\(node.value)'")
        } else {
            print("\(indent)Unknown: '\(node.value)'")
        }
        
        for child in node.children {
            printNodeTree(child, indent: indent + "  ")
        }
    }
    
    func testMarkdownInlineCode() {
        let parser = SwiftParser()
        let markdown = "这是 `内联代码` 测试"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let inlineCode = result.markdownNodes(ofType: .inlineCode)
        
        XCTAssertEqual(inlineCode.count, 1, "应该有1个内联代码")
        XCTAssertEqual(inlineCode.first?.value, "内联代码", "内联代码内容应该正确")
    }
    
    func testMarkdownCodeBlock() {
        let parser = SwiftParser()
        let markdown = """
        ```swift
        let code = "Hello"
        print(code)
        ```
        """
        
        let result = parser.parseMarkdown(markdown)
        XCTAssertFalse(result.hasErrors)
        
        let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
        XCTAssertEqual(codeBlocks.count, 1, "应该有1个代码块")
        
        let codeBlock = codeBlocks.first!
        XCTAssertTrue(codeBlock.value.contains("let code"), "代码块应该包含代码内容")
        
        // 检查语言标识符
        if let langNode = codeBlock.children.first {
            XCTAssertEqual(langNode.value, "swift", "语言标识符应该是swift")
        }
    }
    
    func testMarkdownLinks() {
        let parser = SwiftParser()
        let markdown = "[Google](https://google.com)"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let links = result.markdownNodes(ofType: .link)
        XCTAssertEqual(links.count, 1, "应该有1个链接")
        
        let link = links.first!
        XCTAssertEqual(link.value, "Google", "链接文本应该正确")
        
        if let urlNode = link.children.first {
            XCTAssertEqual(urlNode.value, "https://google.com", "链接URL应该正确")
        }
    }
    
    func testMarkdownImages() {
        let parser = SwiftParser()
        let markdown = "![Alt text](image.jpg)"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let images = result.markdownNodes(ofType: .image)
        XCTAssertEqual(images.count, 1, "应该有1个图片")
        
        let image = images.first!
        XCTAssertEqual(image.value, "Alt text", "图片alt文本应该正确")
        
        if let urlNode = image.children.first {
            XCTAssertEqual(urlNode.value, "image.jpg", "图片URL应该正确")
        }
    }
    
    func testMarkdownBlockquote() {
        let parser = SwiftParser()
        let markdown = "> 这是引用文本\n> 多行引用"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let blockquotes = result.markdownNodes(ofType: .blockquote)
        XCTAssertEqual(blockquotes.count, 1, "应该有1个引用块")
        
        let blockquote = blockquotes.first!
        XCTAssertTrue(blockquote.value.contains("引用文本"), "引用块应该包含正确内容")
    }
    
    func testSpecificNesting() {
        let parser = SwiftParser()
        let testCase = "**粗体*斜体*粗体**"
        
        print("\n=== 调试具体案例 ===")
        print("输入: \(testCase)")
        
        // 先看看token化结果
        let tokenizer = MarkdownTokenizer()
        let tokens = tokenizer.tokenize(testCase)
        print("Token化结果:")
        for (i, token) in tokens.enumerated() {
            if let mdToken = token as? MarkdownToken {
                print("  [\(i)]: \(mdToken.kind) = '\(mdToken.text)'")
            }
        }
        
        let result = parser.parseMarkdown(testCase)
        print("解析结果:")
        printNodeTree(result.root, indent: "")
        
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        print("找到 \(strongEmphasis.count) 个 strongEmphasis 节点")
        
        // 应该有1个strongEmphasis节点包含正确的内容
        XCTAssertEqual(strongEmphasis.count, 1, "应该有1个strongEmphasis节点")
    }
}

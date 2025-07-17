import Foundation

/// Markdown解析示例和用法
public class MarkdownParsingExamples {
    
    /// 基本Markdown解析示例
    public static func basicExample() {
        let markdown = """
        # 标题
        
        这是一个**粗体**文本和*斜体*文本的段落。
        
        ## 代码示例
        
        ```swift
        let code = "Hello, World!"
        print(code)
        ```
        
        - 列表项1
        - 列表项2
        - 列表项3
        
        > 这是一个引用块
        > 包含多行内容
        
        [链接文本](https://example.com "标题")
        
        ![图片alt](image.jpg "图片标题")
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        print("解析结果:")
        print("- 是否有错误: \(result.hasErrors)")
        print("- 错误数量: \(result.errors.count)")
        print("- 根节点类型: \(result.root.type)")
        print("- 子节点数量: \(result.root.children.count)")
        
        // 遍历所有节点
        result.root.traverseDepthFirst { node in
            if let mdElement = node.type as? MarkdownElement {
                print("节点: \(mdElement.description) - 值: '\(node.value)'")
            }
        }
    }
    
    /// 查找特定类型节点的示例
    public static func findSpecificNodesExample() {
        let markdown = """
        # 主标题
        
        ## 子标题
        
        ### 小标题
        
        这是段落文本。
        
        ```python
        print("Hello")
        ```
        
        - 项目1
        - 项目2
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // 查找所有标题
        let headers = result.markdownNodes(ofType: .header1) + 
                     result.markdownNodes(ofType: .header2) + 
                     result.markdownNodes(ofType: .header3)
        
        print("找到 \(headers.count) 个标题:")
        for header in headers {
            print("- \(header.value)")
        }
        
        // 查找所有代码块
        let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
        print("找到 \(codeBlocks.count) 个代码块:")
        for codeBlock in codeBlocks {
            print("- 语言: \(codeBlock.children.first?.value ?? "未指定")")
            print("- 内容: \(codeBlock.value)")
        }
        
        // 查找所有列表
        let lists = result.markdownNodes(ofType: .unorderedList)
        print("找到 \(lists.count) 个无序列表:")
        for list in lists {
            print("- 包含 \(list.children.count) 个项目")
        }
    }
    
    /// 表格解析示例（GFM扩展）
    public static func tableExample() {
        let markdown = """
        | 姓名 | 年龄 | 城市 |
        |------|------|------|
        | 张三 | 25   | 北京 |
        | 李四 | 30   | 上海 |
        | 王五 | 35   | 广州 |
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        let tables = result.markdownNodes(ofType: .table)
        print("找到 \(tables.count) 个表格:")
        
        for table in tables {
            print("表格包含 \(table.children.count) 行:")
            for (rowIndex, row) in table.children.enumerated() {
                if let tableRow = row.type as? MarkdownElement, tableRow == .tableRow {
                    print("  行 \(rowIndex + 1): \(row.children.count) 列")
                    for (colIndex, cell) in row.children.enumerated() {
                        print("    列 \(colIndex + 1): '\(cell.value)'")
                    }
                }
            }
        }
    }
    
    /// 链接解析示例
    public static func linkExample() {
        let markdown = """
        这里有几种不同类型的链接:
        
        1. 内联链接: [Google](https://google.com "搜索引擎")
        2. 引用链接: [GitHub][github]
        3. 简化引用: [GitHub][]
        4. 自动链接: <https://example.com>
        5. 图片: ![Logo](logo.png "公司Logo")
        
        [github]: https://github.com "代码托管平台"
        [GitHub]: https://github.com
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // 查找所有链接
        let links = result.markdownNodes(ofType: .link)
        print("找到 \(links.count) 个链接:")
        for link in links {
            print("- 文本: '\(link.value)'")
            if let urlNode = link.children.first {
                print("  URL: '\(urlNode.value)'")
            }
            if link.children.count > 1 {
                print("  标题: '\(link.children[1].value)'")
            }
        }
        
        // 查找所有图片
        let images = result.markdownNodes(ofType: .image)
        print("找到 \(images.count) 个图片:")
        for image in images {
            print("- Alt文本: '\(image.value)'")
            if let urlNode = image.children.first {
                print("  URL: '\(urlNode.value)'")
            }
        }
        
        // 查找所有自动链接
        let autolinks = result.markdownNodes(ofType: .autolink)
        print("找到 \(autolinks.count) 个自动链接:")
        for autolink in autolinks {
            print("- URL: '\(autolink.value)'")
        }
        
        // 查找链接引用定义
        let linkRefs = result.markdownNodes(ofType: .linkReferenceDefinition)
        print("找到 \(linkRefs.count) 个链接引用定义:")
        for linkRef in linkRefs {
            print("- 标签: '\(linkRef.value)'")
            if let urlNode = linkRef.children.first {
                print("  URL: '\(urlNode.value)'")
            }
        }
    }
    
    /// 强调和代码示例
    public static func emphasisAndCodeExample() {
        let markdown = """
        这里有各种强调和代码:
        
        *斜体文本* 和 _另一种斜体_
        
        **粗体文本** 和 __另一种粗体__
        
        ~~删除线文本~~
        
        `内联代码` 和一些 `其他代码`
        
        ```swift
        // 这是一个代码块
        func hello() {
            print("Hello, World!")
        }
        ```
        
            // 这是缩进代码块
            let x = 42
            print(x)
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // 查找强调
        let emphasis = result.markdownNodes(ofType: .emphasis)
        print("找到 \(emphasis.count) 个斜体:")
        for em in emphasis {
            print("- '\(em.value)'")
        }
        
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        print("找到 \(strongEmphasis.count) 个粗体:")
        for strong in strongEmphasis {
            print("- '\(strong.value)'")
        }
        
        let strikethrough = result.markdownNodes(ofType: .strikethrough)
        print("找到 \(strikethrough.count) 个删除线:")
        for strike in strikethrough {
            print("- '\(strike.value)'")
        }
        
        // 查找代码
        let inlineCode = result.markdownNodes(ofType: .inlineCode)
        print("找到 \(inlineCode.count) 个内联代码:")
        for code in inlineCode {
            print("- '\(code.value)'")
        }
        
        let fencedCode = result.markdownNodes(ofType: .fencedCodeBlock)
        print("找到 \(fencedCode.count) 个围栏代码块:")
        for code in fencedCode {
            if let lang = code.children.first {
                print("- 语言: '\(lang.value)'")
            }
            print("- 内容: '\(code.value)'")
        }
        
        let indentedCode = result.markdownNodes(ofType: .codeBlock)
        print("找到 \(indentedCode.count) 个缩进代码块:")
        for code in indentedCode {
            print("- 内容: '\(code.value)'")
        }
    }
    
    /// 运行所有示例
    public static func runAllExamples() {
        print("=== 基本解析示例 ===")
        basicExample()
        
        print("\n=== 查找特定节点示例 ===")
        findSpecificNodesExample()
        
        print("\n=== 表格解析示例 ===")
        tableExample()
        
        print("\n=== 链接解析示例 ===")
        linkExample()
        
        print("\n=== 强调和代码示例 ===")
        emphasisAndCodeExample()
    }
}

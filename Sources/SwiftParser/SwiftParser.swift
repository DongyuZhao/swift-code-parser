import Foundation

/// SwiftParser - A Swift parsing framework
public struct SwiftParser {
    public init() {}

    public func parse(_ source: String, language: CodeLanguage) -> ParsedSource {
        let root = CodeNode(type: language.rootElement, value: "")
        let parser = CodeParser(language: language)
        let result = parser.parse(source, rootNode: root)
        return ParsedSource(content: source, root: result.node, errors: result.context.errors)
    }
    
    /// 便捷方法：解析Markdown文本
    public func parseMarkdown(_ markdown: String) -> ParsedSource {
        let language = MarkdownLanguage()
        return parse(markdown, language: language)
    }
    
    /// 便捷方法：解析CommonMark规范的Markdown文本（不包括GFM扩展）
    public func parseCommonMark(_ markdown: String) -> ParsedSource {
        let language = MarkdownLanguage()
        // 可以在这里自定义consumer配置
        return parse(markdown, language: language)
    }
}

/// Represents a parsed source file
public struct ParsedSource {
    public let content: String
    public let root: CodeNode
    public let errors: [CodeError]

    public init(content: String, root: CodeNode, errors: [CodeError] = []) {
        self.content = content
        self.root = root
        self.errors = errors
    }
    
    /// 检查是否有解析错误
    public var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    /// 获取所有指定类型的节点
    public func nodes(ofType elementType: any CodeElement.Type) -> [CodeNode] {
        return root.findAll { node in
            type(of: node.type) == elementType
        }
    }
    
    /// 获取所有Markdown元素节点
    public func markdownNodes(ofType elementType: MarkdownElement) -> [CodeNode] {
        return root.findAll { node in
            if let mdElement = node.type as? MarkdownElement {
                return mdElement == elementType
            }
            return false
        }
    }
}

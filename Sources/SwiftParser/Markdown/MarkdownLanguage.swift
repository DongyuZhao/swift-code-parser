import Foundation

/// Markdown语言实现，符合CommonMark规范
public class MarkdownLanguage: CodeLanguage {
    
    public let tokenizer: CodeTokenizer
    public let consumers: [CodeTokenConsumer]
    public let rootElement: any CodeElement
    
    public init() {
        self.tokenizer = MarkdownTokenizer()
        self.rootElement = MarkdownElement.document
        
        // 按优先级顺序组织consumers
        // 块级元素优先级较高，因为它们通常在行首
        self.consumers = [
            // 1. 块级元素 (Block-level elements) - 最高优先级
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownTableConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // 2. 高优先级内联元素 (High priority inline elements)
            MarkdownInlineCodeConsumer(),
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownStrikethroughConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // 3. 换行和文本处理 - 较低优先级
            MarkdownNewlineConsumer(),
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            
            // 4. 兜底处理 - 最低优先级
            MarkdownFallbackConsumer()
        ]
    }
    
    /// 创建默认的文档根节点
    public func createDocumentNode() -> CodeNode {
        return CodeNode(type: MarkdownElement.document, value: "")
    }
    
    /// 解析Markdown文本
    public func parse(_ text: String) -> (node: CodeNode, errors: [CodeError]) {
        let parser = CodeParser(language: self)
        let rootNode = createDocumentNode()
        let result = parser.parse(text, rootNode: rootNode)
        return (result.node, result.context.errors)
    }
}

/// Markdown Consumer工厂类，用于创建和管理不同类型的Consumer
public class MarkdownConsumerFactory {
    
    /// 创建所有标准Markdown consumers
    public static func createStandardConsumers() -> [CodeTokenConsumer] {
        return [
            // 块级元素
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownTableConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // 内联元素
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownInlineCodeConsumer(),
            MarkdownStrikethroughConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // 文本处理
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            MarkdownFallbackConsumer()
        ]
    }
    
    /// 创建只包含基础CommonMark规范的consumers（不包括GFM扩展）
    public static func createCommonMarkConsumers() -> [CodeTokenConsumer] {
        return [
            // 基础块级元素
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // 基础内联元素
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownInlineCodeConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // 文本处理
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            MarkdownFallbackConsumer()
        ]
    }
    
    /// 创建GitHub Flavored Markdown (GFM) 扩展consumers
    public static func createGFMExtensions() -> [CodeTokenConsumer] {
        return [
            MarkdownTableConsumer(),
            MarkdownStrikethroughConsumer()
        ]
    }
    
    /// 创建自定义consumer配置
    public static func createCustomConsumers(
        includeHeaders: Bool = true,
        includeCodeBlocks: Bool = true,
        includeBlockquotes: Bool = true,
        includeLists: Bool = true,
        includeLinks: Bool = true,
        includeImages: Bool = true,
        includeEmphasis: Bool = true,
        includeTables: Bool = false,
        includeStrikethrough: Bool = false
    ) -> [CodeTokenConsumer] {
        
        var consumers: [CodeTokenConsumer] = []
        
        // 块级元素
        if includeHeaders {
            consumers.append(MarkdownHeaderConsumer())
        }
        if includeCodeBlocks {
            consumers.append(MarkdownCodeBlockConsumer())
        }
        if includeBlockquotes {
            consumers.append(MarkdownBlockquoteConsumer())
        }
        if includeLists {
            consumers.append(MarkdownListConsumer())
        }
        if includeTables {
            consumers.append(MarkdownTableConsumer())
        }
        
        consumers.append(MarkdownHorizontalRuleConsumer())
        consumers.append(MarkdownLinkReferenceConsumer())
        
        // 内联元素
        if includeLinks {
            consumers.append(MarkdownLinkConsumer())
        }
        if includeImages {
            consumers.append(MarkdownImageConsumer())
        }
        if includeEmphasis {
            consumers.append(MarkdownEmphasisConsumer())
        }
        if includeStrikethrough {
            consumers.append(MarkdownStrikethroughConsumer())
        }
        
        consumers.append(MarkdownAutolinkConsumer())
        consumers.append(MarkdownInlineCodeConsumer())
        consumers.append(MarkdownHTMLInlineConsumer())
        
        // 基础处理
        consumers.append(MarkdownLineBreakConsumer())
        consumers.append(MarkdownParagraphConsumer())
        consumers.append(MarkdownTextConsumer())
        consumers.append(MarkdownFallbackConsumer())
        
        return consumers
    }
}

/// 部分节点处理器，用于处理前缀歧义情况
public class MarkdownPartialNodeResolver {
    
    /// 解析部分链接节点
    public static func resolvePartialLink(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialLink else { return nil }
        
        // 这里可以实现更复杂的链接解析逻辑
        // 比如查找链接引用定义等
        
        // 简单实现：将部分链接转换为普通文本
        return CodeNode(type: MarkdownElement.text, value: "[" + partialNode.value + "]")
    }
    
    /// 解析部分图片节点
    public static func resolvePartialImage(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialImage else { return nil }
        
        // 简单实现：将部分图片转换为普通文本
        return CodeNode(type: MarkdownElement.text, value: "![" + partialNode.value + "]")
    }
    
    /// 解析部分强调节点
    public static func resolvePartialEmphasis(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialEmphasis else { return nil }
        
        // 简单实现：将部分强调转换为普通文本
        return CodeNode(type: MarkdownElement.text, value: "*" + partialNode.value + "*")
    }
    
    /// 解析所有部分节点
    public static func resolveAllPartialNodes(in rootNode: CodeNode, context: CodeContext) {
        rootNode.traverseDepthFirst { node in
            guard let element = node.type as? MarkdownElement, element.isPartial else { return }
            
            var resolvedNode: CodeNode?
            
            switch element {
            case .partialLink:
                resolvedNode = resolvePartialLink(node, in: context)
            case .partialImage:
                resolvedNode = resolvePartialImage(node, in: context)
            case .partialEmphasis:
                resolvedNode = resolvePartialEmphasis(node, in: context)
            default:
                break
            }
            
            if let resolved = resolvedNode, let parent = node.parent {
                // 替换部分节点
                if let index = parent.children.firstIndex(where: { $0 === node }) {
                    parent.replaceChild(at: index, with: resolved)
                }
            }
        }
    }
}

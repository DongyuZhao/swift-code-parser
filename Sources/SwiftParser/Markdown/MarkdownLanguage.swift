import Foundation

/// Markdown language implementation following the CommonMark specification
public class MarkdownLanguage: CodeLanguage {
    
    public let tokenizer: CodeTokenizer
    public let consumers: [CodeTokenConsumer]
    public let rootElement: any CodeElement
    
    public init() {
        self.tokenizer = MarkdownTokenizer()
        self.rootElement = MarkdownElement.document
        
        // Consumers are ordered by priority
        // Block-level elements have higher priority as they typically start a line
        self.consumers = [
            // 1. Block-level elements - highest priority
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownTableConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // 2. High priority inline elements
            MarkdownInlineCodeConsumer(),
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownStrikethroughConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // 3. Line breaks and text handling - lower priority
            MarkdownNewlineConsumer(),
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            
            // 4. Fallback handling - lowest priority
            MarkdownFallbackConsumer()
        ]
    }
    
    /// Create the default document root node
    public func createDocumentNode() -> CodeNode {
        return CodeNode(type: MarkdownElement.document, value: "")
    }
    
    /// Parse Markdown text
    public func parse(_ text: String) -> (node: CodeNode, errors: [CodeError]) {
        let parser = CodeParser(language: self)
        let rootNode = createDocumentNode()
        let result = parser.parse(text, rootNode: rootNode)
        return (result.node, result.context.errors)
    }
}

/// Factory class used to create and manage different consumers
public class MarkdownConsumerFactory {
    
    /// Create all standard Markdown consumers
    public static func createStandardConsumers() -> [CodeTokenConsumer] {
        return [
            // Block-level elements
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownTableConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // Inline elements
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownInlineCodeConsumer(),
            MarkdownStrikethroughConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // Text handling
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            MarkdownFallbackConsumer()
        ]
    }
    
    /// Create consumers containing only basic CommonMark support (no GFM extensions)
    public static func createCommonMarkConsumers() -> [CodeTokenConsumer] {
        return [
            // Core block-level elements
            MarkdownHeaderConsumer(),
            MarkdownCodeBlockConsumer(),
            MarkdownBlockquoteConsumer(),
            MarkdownListConsumer(),
            MarkdownHorizontalRuleConsumer(),
            MarkdownLinkReferenceConsumer(),
            
            // Core inline elements
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownInlineCodeConsumer(),
            MarkdownHTMLInlineConsumer(),
            
            // Text handling
            MarkdownLineBreakConsumer(),
            MarkdownParagraphConsumer(),
            MarkdownTextConsumer(),
            MarkdownFallbackConsumer()
        ]
    }
    
    /// Create consumers for GitHub Flavored Markdown (GFM) extensions
    public static func createGFMExtensions() -> [CodeTokenConsumer] {
        return [
            MarkdownTableConsumer(),
            MarkdownStrikethroughConsumer()
        ]
    }
    
    /// Create a custom consumer configuration
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
        
        // Block-level elements
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
        
        // Inline elements
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
        
        // Basic handling
        consumers.append(MarkdownLineBreakConsumer())
        consumers.append(MarkdownParagraphConsumer())
        consumers.append(MarkdownTextConsumer())
        consumers.append(MarkdownFallbackConsumer())
        
        return consumers
    }
}

/// Partial node resolver used to handle prefix ambiguities
public class MarkdownPartialNodeResolver {
    
    /// Resolve a partial link node
    public static func resolvePartialLink(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialLink else { return nil }
        
        // More complex link parsing could be implemented here,
        // such as looking up link reference definitions.
        // Simple implementation: convert the partial link to plain text
        return CodeNode(type: MarkdownElement.text, value: "[" + partialNode.value + "]")
    }
    
    /// Resolve a partial image node
    public static func resolvePartialImage(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialImage else { return nil }
        
        // Simple implementation: convert the partial image to plain text
        return CodeNode(type: MarkdownElement.text, value: "![" + partialNode.value + "]")
    }
    
    /// Resolve a partial emphasis node
    public static func resolvePartialEmphasis(_ partialNode: CodeNode, in context: CodeContext) -> CodeNode? {
        guard partialNode.type as? MarkdownElement == .partialEmphasis else { return nil }
        
        // Simple implementation: convert the partial emphasis to plain text
        return CodeNode(type: MarkdownElement.text, value: "*" + partialNode.value + "*")
    }
    
    /// Resolve all partial nodes
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
                // Replace the partial node
                if let index = parent.children.firstIndex(where: { $0 === node }) {
                    parent.replaceChild(at: index, with: resolved)
                }
            }
        }
    }
}

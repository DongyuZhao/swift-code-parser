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
    
    /// Convenience method: parse Markdown text
    public func parseMarkdown(_ markdown: String) -> ParsedSource {
        let language = MarkdownLanguage()
        return parse(markdown, language: language)
    }
    
    /// Convenience method: parse CommonMark Markdown (without GFM extensions)
    public func parseCommonMark(_ markdown: String) -> ParsedSource {
        let language = MarkdownLanguage()
        // Custom consumer configuration can be added here
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
    
    /// Check if there were parse errors
    public var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    /// Get all nodes of the given element type
    public func nodes(ofType elementType: any CodeElement.Type) -> [CodeNode] {
        return root.findAll { node in
            type(of: node.type) == elementType
        }
    }
    
    /// Get all Markdown element nodes
    public func markdownNodes(ofType elementType: MarkdownElement) -> [CodeNode] {
        return root.findAll { node in
            if let mdElement = node.type as? MarkdownElement {
                return mdElement == elementType
            }
            return false
        }
    }
}

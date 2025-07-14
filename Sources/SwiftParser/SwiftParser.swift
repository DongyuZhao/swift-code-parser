import Foundation

/// SwiftParser - A Swift parsing framework
public struct SwiftParser {
    public init() {}

    public func parse(_ source: String, language: CodeLanguage) -> ParsedSource {
        let root = CodeNode(type: language.rootElement, value: "")
        let parser = CodeParser(tokenizer: language.tokenizer, builders: language.builders, expressionBuilders: language.expressionBuilders)
        let result = parser.parse(source, rootNode: root)
        return ParsedSource(content: source, root: result.node, errors: result.context.errors)
    }

    /// Convenience method using Python language by default
    public func parse(_ source: String) -> ParsedSource {
        return parse(source, language: PythonLanguage())
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
}

import Foundation

/// SwiftParser - A Swift parsing framework
public struct SwiftParser<Node: CodeNodeElement, Token: CodeTokenElement> where Node: CodeNodeElement, Token: CodeTokenElement {
    public init() {}

    public func parse(_ source: String, language: any CodeLanguage<Node, Token>) -> ParsedSource<Node> {
        let root = language.root(of: source)
        let parser = CodeParser(language: language)
        let result = parser.parse(source, root: root)
        return ParsedSource(content: source, root: result.node, errors: result.context.errors)
    }
}

/// Represents a parsed source file
public struct ParsedSource<Node> where Node: CodeNodeElement {
    public let content: String
    public let root: CodeNode<Node>
    public let errors: [CodeError]

    public init(content: String, root: CodeNode<Node>, errors: [CodeError] = []) {
        self.content = content
        self.root = root
        self.errors = errors
    }
}

import Foundation

/// SwiftParser - A Swift parsing framework
public struct SwiftParser<Node: CodeNodeElement, Token: CodeTokenElement> where Node: CodeNodeElement, Token: CodeTokenElement {
    public init() {}

    public static func parse(_ source: String, language: any CodeLanguage<Node, Token>) -> CodeParseResult<Node, Token> {
        let parser = CodeParser(language: language)
        return parser.parse(source, language: language)
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

import Foundation

/// Markdown token definitions
public enum MarkdownTokenKind: String, CaseIterable {
    // Basic character classes
    case text
    case whitespace
    case newline
    case eof
    
    // Header related
    case hash           // #
    case headerText
    
    // List related
    case asterisk       // *
    case dash           // -
    case plus           // +
    case digit          // 0-9
    case dot            // .
    case rightParen     // )
    
    // Task list markers (GFM extension)
    case taskListMarker // [ ] or [x] or [X]
    
    // Emphasis related
    case underscore     // _
    
    // Code related
    case backtick       // `
    case tildeTriple    // ~~~
    case indentedCode   // 4+ spaces at line start
    
    // Blockquote related
    case greaterThan    // >
    
    // Link related
    case leftBracket    // [
    case rightBracket   // ]
    case leftParen      // (
    case rightParen2    // )
    case exclamation    // !
    
    // HTML related
    case leftAngle      // <
    case rightAngle     // >
    case htmlTag
    
    // Table related
    case pipe           // |
    case colon          // :
    
    // Horizontal rule related
    case horizontalRule // --- or *** or ___
    
    // Escape related
    case backslash      // \
    case escaped
    
    // Others
    case ampersand      // &
    case entityRef
    case charRef
}

public struct MarkdownToken: CodeToken {
    public let kind: MarkdownTokenKind
    public let text: String
    public let range: Range<String.Index>
    public var lineNumber: Int = 0
    public var columnNumber: Int = 0
    public var isAtLineStart: Bool = false
    public var indentLevel: Int = 0
    
    public var kindDescription: String {
        return kind.rawValue
    }
    
    public init(kind: MarkdownTokenKind, text: String, range: Range<String.Index>) {
        self.kind = kind
        self.text = text
        self.range = range
    }
    
    public init(kind: MarkdownTokenKind, text: String, range: Range<String.Index>, 
                lineNumber: Int, columnNumber: Int, isAtLineStart: Bool = false, indentLevel: Int = 0) {
        self.kind = kind
        self.text = text
        self.range = range
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.isAtLineStart = isAtLineStart
        self.indentLevel = indentLevel
    }
}

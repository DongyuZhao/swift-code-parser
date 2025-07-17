import Foundation

/// Markdown Token类型定义
public enum MarkdownTokenKind: String, CaseIterable {
    // 基础字符类
    case text
    case whitespace
    case newline
    case eof
    
    // 标题相关
    case hash           // #
    case headerText
    
    // 列表相关
    case asterisk       // *
    case dash           // -
    case plus           // +
    case digit          // 0-9
    case dot            // .
    case rightParen     // )
    
    // Task list相关 (GFM extension)
    case taskListMarker // [ ] or [x] or [X]
    
    // 强调相关
    case underscore     // _
    
    // 代码相关
    case backtick       // `
    case tildeTriple    // ~~~
    case indentedCode   // 4+ spaces at line start
    
    // 引用相关
    case greaterThan    // >
    
    // 链接相关
    case leftBracket    // [
    case rightBracket   // ]
    case leftParen      // (
    case rightParen2    // )
    case exclamation    // !
    
    // HTML相关
    case leftAngle      // <
    case rightAngle     // >
    case htmlTag
    
    // 表格相关
    case pipe           // |
    case colon          // :
    
    // 水平线相关
    case horizontalRule // --- or *** or ___
    
    // 转义相关
    case backslash      // \
    case escaped
    
    // 其他
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

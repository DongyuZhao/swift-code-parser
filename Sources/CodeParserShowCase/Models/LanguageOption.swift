import SwiftUI

// MARK: - Language Options
enum LanguageOption: String, CaseIterable, Hashable {
    case markdown = "markdown"
    case swift = "swift"
    case json = "json"
    case xml = "xml"
    
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .swift: return "Swift"
        case .json: return "JSON"
        case .xml: return "XML"
        }
    }
    
    var description: String {
        switch self {
        case .markdown: return "CommonMark with extensions"
        case .swift: return "Swift programming language"
        case .json: return "JavaScript Object Notation"
        case .xml: return "eXtensible Markup Language"
        }
    }
    
    var iconName: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .swift: return "swift"
        case .json: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var color: Color {
        switch self {
        case .markdown: return .blue
        case .swift: return .orange
        case .json: return .green
        case .xml: return .purple
        }
    }
}

// MARK: - Detail Tabs
enum DetailTab: String, CaseIterable {
    case input = "input"
    case result = "result"
    case tokens = "tokens"
    case ast = "ast"
}

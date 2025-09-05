import CodeParserCore
import Foundation

/// Minimal construction state for Markdown language
/// Only contains state that cannot be derived from the AST (context.current)
public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  /// Reference link definitions storage for resolving reference links
  /// Key is normalized reference identifier (case-insensitive, whitespace collapsed)
  /// Note: This cannot be derived from AST since reference definitions may appear
  /// anywhere in the document and need to be available for link resolution
  public var referenceDefinitions: [String: (url: String, title: String)] = [:]

  public init() {}
  
  /// Add a reference definition with normalized identifier
  public func addReferenceDefinition(identifier: String, url: String, title: String) {
    let normalizedId = normalizeReferenceIdentifier(identifier)
    referenceDefinitions[normalizedId] = (url: url, title: title)
  }
  
  /// Look up a reference definition by identifier
  public func getReferenceDefinition(for identifier: String) -> (url: String, title: String)? {
    let normalizedId = normalizeReferenceIdentifier(identifier)
    return referenceDefinitions[normalizedId]
  }
  
  /// Normalize reference identifier according to CommonMark spec:
  /// - Case insensitive
  /// - Collapse whitespace and newlines to single spaces
  /// - Trim leading/trailing whitespace
  private func normalizeReferenceIdentifier(_ identifier: String) -> String {
    return identifier
      .lowercased()
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

/// Information about a pending reference link definition being parsed across multiple lines
public struct PendingReferenceDefinition {
  public let identifier: String
  public let referenceNode: ReferenceNode
  public var hasDestination: Bool
  public var hasTitle: Bool
  public let originalLineTokens: [any CodeToken<MarkdownTokenElement>] // For fallback to paragraph
  
  public init(identifier: String, referenceNode: ReferenceNode, originalLineTokens: [any CodeToken<MarkdownTokenElement>]) {
    self.identifier = identifier
    self.referenceNode = referenceNode
    self.hasDestination = false
    self.hasTitle = false
    self.originalLineTokens = originalLineTokens
  }
}

/// Information about an open fenced code block
public struct OpenFenceInfo {
  public let character: String
  public let length: Int
  public let indentation: Int
  public let codeBlock: CodeBlockNode
  public let containerContext: MarkdownNodeBase?  // Track the container this fence is inside
  
  public init(character: String, length: Int, indentation: Int, codeBlock: CodeBlockNode, containerContext: MarkdownNodeBase? = nil) {
    self.character = character
    self.length = length
    self.indentation = indentation
    self.codeBlock = codeBlock
    self.containerContext = containerContext
  }
}

/// Information about an open HTML block
public struct OpenHTMLBlockInfo {
  public let type: Int // HTML block type (1-7)
  public let endCondition: String? // What string ends this block
  public let htmlBlock: HTMLBlockNode
  
  public init(type: Int, endCondition: String?, htmlBlock: HTMLBlockNode) {
    self.type = type
    self.endCondition = endCondition
    self.htmlBlock = htmlBlock
  }
}

/// Information about detected HTML block type
public struct HTMLBlockTypeInfo {
  public let type: Int
  public let name: String
  public let closedOnSameLine: Bool
  public let endCondition: String?
  
  public init(type: Int, name: String, closedOnSameLine: Bool, endCondition: String? = nil) {
    self.type = type
    self.name = name
    self.closedOnSameLine = closedOnSameLine
    self.endCondition = endCondition
  }
}

/// Enhanced list context information for better nesting and indentation management
public struct ListContextInfo {
  /// The list node itself
  public let list: ListNode
  /// The parent list item that contains this list (nil for top-level lists)
  public let parentListItem: ListItemNode?
  /// The calculated indentation level for content in this list context
  public let contentIndent: Int
  /// The nesting level (1 for top-level, 2 for first nested, etc.)
  public let level: Int
  /// The marker type for compatibility checking
  public let markerType: String
  
  public init(list: ListNode, parentListItem: ListItemNode?, contentIndent: Int, level: Int, markerType: String) {
    self.list = list
    self.parentListItem = parentListItem
    self.contentIndent = contentIndent
    self.level = level
    self.markerType = markerType
  }
}

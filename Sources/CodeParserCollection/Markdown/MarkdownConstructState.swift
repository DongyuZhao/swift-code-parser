import CodeParserCore
import Foundation

/// Main construction state for Markdown language with line-based processing
public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // Current token index in the line
  public var position: Int = 0
  // Flag indicates if the block builders should run another round on the same line.
  public var refreshed: Bool = false
  // Flag indicates if the current line is being reprocessed after partial consumption
  public var isPartialLine: Bool = false
  
  // Fenced code block state
  public var openFence: OpenFenceInfo?
  
  // HTML block state
  public var openHTMLBlock: OpenHTMLBlockInfo?
  
  /// Stack for nested list processing
  public var listStack: [ListNode] = []
  public var currentDefinitionList: DefinitionListNode?

  /// Indicates the last consumed line break formed a blank line (two or more consecutive newlines)
  public var lastWasBlankLine: Bool = false

  /// When a quoted blank line (`>\\n`) is seen inside a blockquote, the next quoted
  /// content should start a new paragraph inside the same blockquote instead of
  /// merging into the previous one.
  public var pendingBlockquoteParagraphSplit: Bool = false

  /// True when the previous quoted line (inside a blockquote) began with a token
  /// that could start a block (e.g., `#`, `-`, `*`, `+`, number.). We use this to
  /// prevent merging the next quoted line into the same paragraph, matching CommonMark
  /// semantics where block-starting constructs introduce a new block.
  public var prevBlockquoteLineWasBlockStart: Bool = false

  /// Reference link definitions storage for resolving reference links
  /// Key is normalized reference identifier (case-insensitive, whitespace collapsed)
  public var referenceDefinitions: [String: (url: String, title: String)] = [:]

  /// Pending reference link definition being parsed across multiple lines
  public var pendingReference: PendingReferenceDefinition?

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
  
  public init(character: String, length: Int, indentation: Int, codeBlock: CodeBlockNode) {
    self.character = character
    self.length = length
    self.indentation = indentation
    self.codeBlock = codeBlock
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

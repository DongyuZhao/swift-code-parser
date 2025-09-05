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
  
  /// Current line tokens being processed - builders can modify these
  /// This allows builders to consume their part and leave remaining tokens for further processing
  public var tokens: [any CodeToken<MarkdownTokenElement>] = []
  
  /// Flag indicating if current line has been fully processed by a builder
  /// When false, MarkdownBlockBuilder should continue processing the remaining tokens
  public var currentLineProcessed: Bool = true

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

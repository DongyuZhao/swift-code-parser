import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - Simple dispatcher that follows CodeNodeBuilder pattern
/// This class acts as a hub that delegates to pluggable CodeNodeBuilder implementations
/// Contains no grammar-related logic - leverages CodeParserCore's tokenizer framework
/// Maintains CodeNodeBuilder protocol compatibility with CodeParserCore
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  private let builders: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>]
  
  /// Initialize with a custom set of builders - this makes the system fully pluggable
  public init(builders: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>]) {
    self.builders = builders
  }
  
  /// Initialize with default builders
  public convenience init() {
    self.init(builders: Self.createDefaultBuilders())
  }
  
  /// Simple implementation that follows CodeNodeBuilder pattern
  /// Delegates to specific builders and lets CodeParserCore handle orchestration
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }
    
    // Try each builder in order until one succeeds
    for builder in builders {
      if builder.build(from: &context) {
        return true
      }
    }
    
    return false
  }
  
  /// Create the default set of Markdown CodeNodeBuilder implementations
  /// These are the standard builders that can be easily customized
  public static func createDefaultBuilders() -> [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>] {
    return [
      // Try indented code blocks first (must come before paragraphs)
      IndentedCodeBlockBuilder(),
      // Try paragraph builder as main content handler
      ParagraphCodeNodeBuilder()
    ]
  }
}
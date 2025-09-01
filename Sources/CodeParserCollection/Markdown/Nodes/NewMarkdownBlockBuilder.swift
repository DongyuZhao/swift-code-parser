import CodeParserCore
import Foundation

/// New MarkdownBlockBuilder that follows CommonMark parsing strategy
/// This replaces the old phase-based architecture with a proper CommonMark-compliant implementation
/// 
/// The new architecture separates concerns:
/// - This class handles the CommonMark parsing algorithm (continuation, closing, opening blocks)
/// - Individual builders handle block-specific logic without grammar specification
/// - The architecture remains fully pluggable for adding new block types
public class NewMarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  private let parser: CommonMarkBlockParser
  
  /// Initialize with a custom set of builders
  public init(builders: [CommonMarkBlockBuilder]) {
    self.parser = CommonMarkBlockParser(builders: builders)
  }
  
  /// Initialize with the standard set of CommonMark builders
  public convenience init() {
    self.init(builders: Self.createStandardBuilders())
  }
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    return parser.build(from: &context)
  }
  
  /// Create the standard set of CommonMark block builders
  /// This replaces the hardcoded rules from the old implementation
  private static func createStandardBuilders() -> [CommonMarkBlockBuilder] {
    return [
      // Container blocks (processed first, higher priority = lower number)
      CommonMarkBlockquoteBuilder(),
      // TODO: Add list builders when implemented
      
      // Leaf blocks
      // TODO: Add EOF builder
      // TODO: Add reference link definition builder
      // TODO: Add fenced code block builder
      // TODO: Add ATX heading builder
      CommonMarkThematicBreakBuilder(),
      // TODO: Add setext heading builder
      // TODO: Add HTML block builder
      // TODO: Add indented code block builder
      
      // Fallback paragraph builder (lowest priority)
      CommonMarkParagraphBuilder()
    ]
  }
}

/// Backwards compatibility - alias to the new implementation
/// This allows existing code to work without changes while using the new architecture
@available(*, deprecated, message: "Use NewMarkdownBlockBuilder instead. This will be removed in a future version.")
public typealias MarkdownBlockBuilderV2 = NewMarkdownBlockBuilder
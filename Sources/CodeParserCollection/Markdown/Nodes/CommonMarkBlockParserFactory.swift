import CodeParserCore
import Foundation

/// Factory for creating CommonMark-compliant block parsers with pluggable builders
/// This class provides a clean separation between the parsing algorithm and block-specific logic
public class CommonMarkBlockParserFactory {
  
  /// Create a standard CommonMark block parser with all built-in builders
  public static func createStandardParser() -> CommonMarkBlockParser {
    let builders: [CommonMarkBlockBuilder] = [
      // Container blocks (higher priority)
      CommonMarkBlockquoteBuilder(),
      // TODO: Add list builders, code blocks, etc.
      
      // Leaf blocks
      CommonMarkThematicBreakBuilder(),
      // TODO: Add ATX headings, setext headings, fenced code blocks, etc.
      
      // Fallback
      CommonMarkParagraphBuilder()
    ]
    
    return CommonMarkBlockParser(builders: builders)
  }
  
  /// Create a custom parser with specific builders
  public static func createCustomParser(with builders: [CommonMarkBlockBuilder]) -> CommonMarkBlockParser {
    return CommonMarkBlockParser(builders: builders)
  }
  
  /// Create a minimal parser with just essential builders for testing
  public static func createMinimalParser() -> CommonMarkBlockParser {
    let builders: [CommonMarkBlockBuilder] = [
      CommonMarkThematicBreakBuilder(),
      CommonMarkParagraphBuilder()
    ]
    
    return CommonMarkBlockParser(builders: builders)
  }
}

/// Registry for managing and discovering CommonMark block builders
/// This allows for dynamic registration of new block types
public class CommonMarkBlockBuilderRegistry {
  private var builders: [String: CommonMarkBlockBuilder] = [:]
  
  public init() {}
  
  /// Register a builder for a specific block type
  public func register(_ builder: CommonMarkBlockBuilder, for blockType: String) {
    builders[blockType] = builder
  }
  
  /// Get a builder for a specific block type
  public func getBuilder(for blockType: String) -> CommonMarkBlockBuilder? {
    return builders[blockType]
  }
  
  /// Get all registered builders
  public func getAllBuilders() -> [CommonMarkBlockBuilder] {
    return Array(builders.values)
  }
  
  /// Create a parser with all registered builders
  public func createParser() -> CommonMarkBlockParser {
    return CommonMarkBlockParser(builders: getAllBuilders())
  }
  
  /// Register all standard CommonMark builders
  public func registerStandardBuilders() {
    register(CommonMarkBlockquoteBuilder(), for: "blockquote")
    register(CommonMarkThematicBreakBuilder(), for: "thematic_break")
    register(CommonMarkParagraphBuilder(), for: "paragraph")
    // TODO: Register other standard builders as they are implemented
  }
}
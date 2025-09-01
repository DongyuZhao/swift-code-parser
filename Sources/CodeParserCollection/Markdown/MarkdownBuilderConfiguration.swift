import CodeParserCore
import Foundation

/// Configuration class for managing Markdown block and inline builders
/// Provides a clean, pluggable way to configure which features are enabled
public class MarkdownBuilderConfiguration {
  
  private var blockBuilders: [MarkdownBlockBuilderProtocol] = []
  private var inlineBuilders: [MarkdownInlineBuilderProtocol] = []
  
  /// Initialize with empty configuration
  public init() {}
  
  /// Initialize with standard CommonMark builders
  public static func standard() -> MarkdownBuilderConfiguration {
    let config = MarkdownBuilderConfiguration()
    config.addStandardBlockBuilders()
    config.addStandardInlineBuilders()
    return config
  }
  
  /// Initialize with minimal builders (only basic text processing)
  public static func minimal() -> MarkdownBuilderConfiguration {
    let config = MarkdownBuilderConfiguration()
    config.addBlockBuilder(MarkdownParagraphBuilder())
    config.addInlineBuilder(MarkdownTextBuilder())
    return config
  }
  
  // MARK: - Block Builder Management
  
  /// Add a block builder to the configuration
  @discardableResult
  public func addBlockBuilder(_ builder: MarkdownBlockBuilderProtocol) -> MarkdownBuilderConfiguration {
    blockBuilders.append(builder)
    return self
  }
  
  /// Remove block builders of a specific type
  @discardableResult
  public func removeBlockBuilder(ofType type: MarkdownNodeElement) -> MarkdownBuilderConfiguration {
    blockBuilders.removeAll { $0.blockType == type }
    return self
  }
  
  /// Add standard block builders for complete CommonMark support
  @discardableResult
  public func addStandardBlockBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addBlockBuilder(MarkdownBlockquoteBuilder())
      .addBlockBuilder(MarkdownThematicBreakBuilder())
      .addBlockBuilder(MarkdownParagraphBuilder())
  }
  
  /// Add core block builders (essential for any Markdown parsing)
  @discardableResult
  public func addCoreBlockBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addBlockBuilder(MarkdownParagraphBuilder())
  }
  
  /// Get configured block builders sorted by priority
  public func getBlockBuilders() -> [MarkdownBlockBuilderProtocol] {
    return blockBuilders.sorted { $0.priority < $1.priority }
  }
  
  /// Get configured block builders with inline processing configured
  public func getConfiguredBlockBuilders() -> [MarkdownBlockBuilderProtocol] {
    return blockBuilders.map { builder in
      // Configure paragraph builders with matching inline processor
      if builder is MarkdownParagraphBuilder {
        return MarkdownParagraphBuilder(inlineProcessor: MarkdownInlineProcessor(configuration: self))
      }
      return builder
    }.sorted { $0.priority < $1.priority }
  }
  
  // MARK: - Inline Builder Management
  
  /// Add an inline builder to the configuration
  @discardableResult
  public func addInlineBuilder(_ builder: MarkdownInlineBuilderProtocol) -> MarkdownBuilderConfiguration {
    inlineBuilders.append(builder)
    return self
  }
  
  /// Remove inline builders of a specific type
  @discardableResult
  public func removeInlineBuilder(ofType type: MarkdownNodeElement) -> MarkdownBuilderConfiguration {
    inlineBuilders.removeAll { $0.inlineType == type }
    return self
  }
  
  /// Add standard inline builders for complete CommonMark support
  @discardableResult
  public func addStandardInlineBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addInlineBuilder(MarkdownCodeSpanBuilder())
      .addInlineBuilder(MarkdownHardLineBreakBuilder())
      .addInlineBuilder(MarkdownEmphasisBuilder())
      .addInlineBuilder(MarkdownStrongBuilder())
      .addInlineBuilder(MarkdownLinkBuilder())
      .addInlineBuilder(MarkdownImageBuilder())
      .addInlineBuilder(MarkdownHTMLInlineBuilder())
      .addInlineBuilder(MarkdownEntityReferenceBuilder())
      .addInlineBuilder(MarkdownTextBuilder())
  }
  
  /// Add core inline builders (essential for any text processing)
  @discardableResult
  public func addCoreInlineBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addInlineBuilder(MarkdownTextBuilder())
  }
  
  /// Add emphasis and strong emphasis builders
  @discardableResult
  public func addEmphasisBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addInlineBuilder(MarkdownEmphasisBuilder())
      .addInlineBuilder(MarkdownStrongBuilder())
  }
  
  /// Add code-related builders
  @discardableResult
  public func addCodeBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addInlineBuilder(MarkdownCodeSpanBuilder())
  }
  
  /// Add link and image builders
  @discardableResult
  public func addLinkBuilders() -> MarkdownBuilderConfiguration {
    return self
      .addInlineBuilder(MarkdownLinkBuilder())
      .addInlineBuilder(MarkdownImageBuilder())
  }
  
  /// Get configured inline builders sorted by priority
  public func getInlineBuilders() -> [MarkdownInlineBuilderProtocol] {
    return inlineBuilders.sorted { $0.priority < $1.priority }
  }
  
  // MARK: - Feature Sets
  
  /// Enable only basic text processing (no formatting)
  @discardableResult
  public func textOnly() -> MarkdownBuilderConfiguration {
    blockBuilders.removeAll()
    inlineBuilders.removeAll()
    return self
      .addCoreBlockBuilders()
      .addCoreInlineBuilders()
  }
  
  /// Enable text with basic formatting (emphasis, strong, code)
  @discardableResult
  public func basicFormatting() -> MarkdownBuilderConfiguration {
    return self
      .textOnly()
      .addEmphasisBuilders()
      .addCodeBuilders()
  }
  
  /// Enable text with links but no other advanced features
  @discardableResult
  public func textWithLinks() -> MarkdownBuilderConfiguration {
    return self
      .basicFormatting()
      .addLinkBuilders()
  }
  
  // MARK: - Validation
  
  /// Validate that the configuration has required builders
  public func validate() throws {
    // Ensure we have at least one block builder
    guard !blockBuilders.isEmpty else {
      throw MarkdownConfigurationError.noBlockBuilders
    }
    
    // Ensure we have at least one inline builder
    guard !inlineBuilders.isEmpty else {
      throw MarkdownConfigurationError.noInlineBuilders
    }
    
    // Ensure we have a paragraph builder (required for fallback)
    guard blockBuilders.contains(where: { $0.blockType == .paragraph }) else {
      throw MarkdownConfigurationError.missingParagraphBuilder
    }
    
    // Ensure we have a text builder (required for fallback)
    guard inlineBuilders.contains(where: { $0.inlineType == .text }) else {
      throw MarkdownConfigurationError.missingTextBuilder
    }
  }
}

/// Errors that can occur during configuration validation
public enum MarkdownConfigurationError: Error, LocalizedError {
  case noBlockBuilders
  case noInlineBuilders
  case missingParagraphBuilder
  case missingTextBuilder
  
  public var errorDescription: String? {
    switch self {
    case .noBlockBuilders:
      return "Configuration must have at least one block builder"
    case .noInlineBuilders:
      return "Configuration must have at least one inline builder"
    case .missingParagraphBuilder:
      return "Configuration must include a paragraph builder for fallback processing"
    case .missingTextBuilder:
      return "Configuration must include a text builder for fallback processing"
    }
  }
}

// MARK: - Convenience Extensions

public extension MarkdownBuilderConfiguration {
  
  /// Factory method for GitHub Flavored Markdown configuration
  static func githubFlavored() -> MarkdownBuilderConfiguration {
    return MarkdownBuilderConfiguration.standard()
      // In a complete implementation, this would add GFM-specific builders
      // like strikethrough, tables, task lists, etc.
  }
  
  /// Factory method for strict CommonMark configuration
  static func strictCommonMark() -> MarkdownBuilderConfiguration {
    return MarkdownBuilderConfiguration.standard()
      // Ensures only CommonMark-compliant features are enabled
  }
  
  /// Factory method for documentation-focused configuration
  static func documentation() -> MarkdownBuilderConfiguration {
    return MarkdownBuilderConfiguration.standard()
      // Could include additional documentation-specific features
  }
}
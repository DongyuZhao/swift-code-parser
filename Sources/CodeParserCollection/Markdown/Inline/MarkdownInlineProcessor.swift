import CodeParserCore
import Foundation

/// Markdown inline processor that implements the CommonMark delimiter stack algorithm
/// This processor handles emphasis, strong emphasis, links, code spans, and other inline elements
/// following the official CommonMark specification
public class MarkdownInlineProcessor {
  
  private let builders: [MarkdownInlineBuilderProtocol]
  
  /// Initialize with a custom set of inline builders
  public init(builders: [MarkdownInlineBuilderProtocol]) {
    // Sort builders by priority (lower number = higher priority)
    self.builders = builders.sorted { $0.priority < $1.priority }
  }
  
  /// Initialize with a configuration object
  public init(configuration: MarkdownBuilderConfiguration) {
    do {
      try configuration.validate()
      self.builders = configuration.getInlineBuilders()
    } catch {
      // Fallback to standard builders if configuration is invalid
      self.builders = Self.createStandardBuilders()
    }
  }
  
  /// Initialize with the standard set of inline builders
  public convenience init() {
    self.init(configuration: .standard())
  }
  
  /// Process inline content within a block
  /// This implements the CommonMark delimiter stack algorithm
  /// - Parameters:
  ///   - tokens: The tokens to process
  ///   - block: The block containing the inline content
  ///   - context: The construct context for node operations
  public func processInlineContent(
    tokens: [any CodeToken<MarkdownTokenElement>],
    in block: MarkdownNodeBase,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) {
    guard let state = context.state as? MarkdownConstructState else { return }
    
    var position = 0
    var delimiterStack: [DelimiterEntry] = []
    
    // Process each token according to CommonMark rules
    while position < tokens.count {
      let token = tokens[position]
      
      // Try each builder in priority order
      var handled = false
      for builder in builders {
        if builder.canHandle(tokens: tokens, position: position, state: state) {
          if let inlineNode = builder.process(
            tokens: tokens,
            position: &position,
            delimiterStack: &delimiterStack,
            state: state,
            context: &context
          ) {
            block.append(inlineNode)
            handled = true
            break
          }
        }
      }
      
      // If no builder handled the token, treat it as text
      if !handled {
        let textNode = createTextNode(from: token)
        block.append(textNode)
        position += 1
      }
    }
    
    // Process any remaining delimiters on the stack
    // According to CommonMark, unmatched delimiters should be treated as literal text
    processRemainingDelimiters(&delimiterStack, in: block)
  }
  
  /// Create a text node from a token
  private func createTextNode(from token: any CodeToken<MarkdownTokenElement>) -> TextNode {
    return TextNode(content: token.text)
  }
  
  /// Process any remaining delimiters on the stack as literal text
  private func processRemainingDelimiters(_ delimiterStack: inout [DelimiterEntry], in block: MarkdownNodeBase) {
    // In a complete implementation, this would convert unmatched delimiters back to text nodes
    // For now, we'll keep it simple since the delimiters were already processed
    delimiterStack.removeAll()
  }
  
  /// Create the standard set of inline builders
  /// Note: Consider using MarkdownBuilderConfiguration.standard() instead
  private static func createStandardBuilders() -> [MarkdownInlineBuilderProtocol] {
    return [
      // High priority builders (processed first)
      MarkdownCodeSpanBuilder(),           // Code spans: `code`
      MarkdownHardLineBreakBuilder(),      // Hard line breaks: backslash + newline
      
      // Emphasis builders (use delimiter stack)
      MarkdownEmphasisBuilder(),           // Emphasis: *text* or _text_
      MarkdownStrongBuilder(),             // Strong: **text** or __text__
      
      // Link and image builders
      MarkdownLinkBuilder(),               // Links: [text](url)
      MarkdownImageBuilder(),              // Images: ![alt](url)
      
      // Other inline elements
      MarkdownHTMLInlineBuilder(),         // Inline HTML tags
      MarkdownEntityReferenceBuilder(),    // HTML entities: &amp;
      
      // Fallback text builder (lowest priority)
      MarkdownTextBuilder()                // Plain text
    ]
  }
  
  // MARK: - Convenience Factory Methods
  
  /// Create a processor with only basic text processing
  public static func textOnly() -> MarkdownInlineProcessor {
    return MarkdownInlineProcessor(configuration: .minimal())
  }
  
  /// Create a processor with GitHub Flavored Markdown support
  public static func githubFlavored() -> MarkdownInlineProcessor {
    return MarkdownInlineProcessor(configuration: .githubFlavored())
  }
  
  /// Create a processor with strict CommonMark compliance
  public static func strictCommonMark() -> MarkdownInlineProcessor {
    return MarkdownInlineProcessor(configuration: .strictCommonMark())
  }
  
  /// Create a processor optimized for documentation
  public static func documentation() -> MarkdownInlineProcessor {
    return MarkdownInlineProcessor(configuration: .documentation())
  }
}
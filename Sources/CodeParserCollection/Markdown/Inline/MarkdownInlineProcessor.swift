import CodeParserCore
import Foundation

/// MarkdownInlineProcessor - Pure dispatcher for Markdown inline processing
/// This class acts as a hub that delegates to pluggable inline builder implementations  
/// Contains no delimiter stack or grammar logic - all parsing logic is in individual builders
/// Follows the CodeParserCore framework principles
public class MarkdownInlineProcessor {
  
  private let builders: [MarkdownInlineBuilderProtocol]
  
  /// Initialize with a custom set of inline builders - this makes the system fully pluggable
  public init(builders: [MarkdownInlineBuilderProtocol]) {
    // Sort builders by priority (lower number = higher priority)
    self.builders = builders.sorted { $0.priority < $1.priority }
  }
  
  /// Initialize with default builders
  public convenience init() {
    self.init(builders: Self.createDefaultBuilders())
  }
  
  /// Process inline content - pure dispatcher without delimiter stack algorithm
  /// Delegates to individual builders which contain their own parsing logic
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
    
    // Simple dispatch loop - each builder handles its own parsing logic
    while position < tokens.count {
      // Try each builder in priority order - pure delegation
      var handled = false
      for builder in builders {
        if builder.canHandle(tokens: tokens, position: position, state: state) {
          // Let the builder handle its own parsing logic including delimiter stack if needed
          var delimiterStack: [DelimiterEntry] = []  // Each builder manages its own stack
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
      
      // If no builder handled the token, use fallback text builder
      if !handled {
        if let textBuilder = builders.first(where: { $0.inlineType == .text }) {
          var delimiterStack: [DelimiterEntry] = []
          if let textNode = textBuilder.process(
            tokens: tokens,
            position: &position,
            delimiterStack: &delimiterStack,
            state: state,
            context: &context
          ) {
            block.append(textNode)
          } else {
            // Ultimate fallback - skip token
            position += 1
          }
        } else {
          // No text builder available - skip token
          position += 1
        }
      }
    }
  }
  
  /// Create the default set of inline builders  
  /// These are the standard builders that can be easily customized
  public static func createDefaultBuilders() -> [MarkdownInlineBuilderProtocol] {
    return [
      // High priority builders (processed first)
      MarkdownCodeSpanBuilder(),           // Code spans: `code`
      MarkdownHardLineBreakBuilder(),      // Hard line breaks: backslash + newline
      
      // Emphasis builders (handle their own delimiter stacks)
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
}
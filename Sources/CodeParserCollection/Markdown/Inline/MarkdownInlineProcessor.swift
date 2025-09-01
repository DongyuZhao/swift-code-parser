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
  
  /// Process inline content using CommonMark delimiter stack algorithm - delegates specific logic to builders
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
    
    // Process each token according to CommonMark delimiter stack algorithm
    while position < tokens.count {
      let token = tokens[position]
      
      // Try each builder in priority order - delegate all specific logic to builders
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
      
      // If no builder handled the token, delegate to text builder as fallback
      if !handled {
        if let textBuilder = builders.first(where: { $0.inlineType == .text }) {
          if let textNode = textBuilder.process(
            tokens: tokens,
            position: &position,
            delimiterStack: &delimiterStack,
            state: state,
            context: &context
          ) {
            block.append(textNode)
          } else {
            // Ultimate fallback - create text node directly and advance
            block.append(createTextNode(from: token))
            position += 1
          }
        } else {
          // No text builder available - create text node directly and advance
          block.append(createTextNode(from: token))
          position += 1
        }
      }
    }
    
    // Process any remaining delimiters on the stack according to CommonMark rules
    // Unmatched delimiters should be treated as literal text
    processRemainingDelimiters(&delimiterStack, in: block)
  }
  
  /// Create a text node from a token - utility method
  private func createTextNode(from token: any CodeToken<MarkdownTokenElement>) -> TextNode {
    return TextNode(content: token.text)
  }
  
  /// Process any remaining delimiters on the stack as literal text
  private func processRemainingDelimiters(_ delimiterStack: inout [DelimiterEntry], in block: MarkdownNodeBase) {
    // Convert unmatched delimiters back to text nodes according to CommonMark rules
    // This is a simplified implementation - a complete one would properly handle all cases
    for delimiter in delimiterStack {
      let textNode = TextNode(content: String(repeating: delimiter.character, count: delimiter.count))
      block.append(textNode)
    }
    delimiterStack.removeAll()
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
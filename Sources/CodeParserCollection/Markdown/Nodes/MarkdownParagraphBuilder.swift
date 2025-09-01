import CodeParserCore
import Foundation

/// Markdown-compliant paragraph builder
/// Handles paragraph blocks which are the default container for text content
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#paragraphs
public class MarkdownParagraphBuilder: MarkdownBlockBuilderProtocol {
  
  public var priority: Int { return 1000 } // Lowest priority - fallback
  public var blockType: MarkdownNodeElement { return .paragraph }
  
  public init() {}
  
  public func canContinue(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // Paragraphs can continue unless the line is blank or starts a new block
    guard block.element == .paragraph else { return false }
    
    // Check if line is blank
    if isBlankLine(line) {
      return false
    }
    
    // Paragraphs continue unless interrupted by other block types
    // The main parser will handle checking other builders first
    return true
  }
  
  public func canStart(
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // Paragraphs can start with any non-blank line that isn't handled by other builders
    // Since this is the fallback builder, it should accept any content
    return !isBlankLine(line)
  }
  
  public func createBlock(
    from line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    // Create a dummy range for now - in a complete implementation this would derive from tokens
    let dummyString = ""
    let range = dummyString.startIndex..<dummyString.endIndex
    let paragraph = ParagraphNode(range: range)
    return paragraph
  }
  
  public func processLine(
    for block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard let paragraph = block as? ParagraphNode else { return false }
    
    // Process inline content using the inline processor
    let inlineProcessor = MarkdownInlineProcessor()
    inlineProcessor.processInlineContent(tokens: line, in: paragraph, context: &context)
    
    // Mark the entire line as consumed
    state.position = line.count
    return true
  }
  
  public func shouldClose(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // Paragraphs close on blank lines or when interrupted by other block types
    return isBlankLine(line)
  }
  
  // MARK: - Private Helper Methods
  
  /// Check if a line is blank (contains only whitespace and newline)
  private func isBlankLine(_ line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    for token in line {
      switch token.element {
      case .whitespaces, .newline:
        continue
      default:
        return false
      }
    }
    return true
  }
  
  /// Check if this is the last line (contains EOF or is empty)
  private func isLastLine(_ line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    return line.isEmpty || line.contains { $0.element == .eof }
  }
}
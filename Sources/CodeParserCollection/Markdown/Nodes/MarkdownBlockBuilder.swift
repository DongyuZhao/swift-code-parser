import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - Pure dispatcher for Markdown block building
/// This class acts as a hub that delegates to pluggable block builder implementations
/// Contains no grammar-related logic - all parsing logic is in individual builders
/// Maintains CodeNodeBuilder protocol compatibility with CodeParserCore
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  private let builders: [MarkdownBlockBuilderProtocol]
  
  /// Initialize with a custom set of builders - this makes the system fully pluggable
  public init(builders: [MarkdownBlockBuilderProtocol]) {
    // Sort builders by priority (lower number = higher priority)
    self.builders = builders.sorted { $0.priority < $1.priority }
  }
  
  /// Initialize with default builders
  public convenience init() {
    self.init(builders: Self.createDefaultBuilders())
  }
  
  /// Pure dispatcher implementation - delegates to appropriate builders without grammar logic
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }
    
    let lines = extractLines(from: context)
    guard !lines.isEmpty else { return false }
    
    // Dispatch each line to appropriate builders
    for line in lines {
      dispatchLine(line, context: &context)
    }
    
    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Dispatch a single line to the appropriate builder - pure delegation without parsing logic
  private func dispatchLine(
    _ line: [any CodeToken<MarkdownTokenElement>], 
    context: inout CodeConstructContext<Node, Token>
  ) {
    guard let state = context.state as? MarkdownConstructState else { return }
    
    // Reset line position for each line
    state.position = 0
    state.isPartialLine = false
    
    // Try each builder in priority order - first one that can handle the line processes it
    for builder in builders {
      if builder.canStart(line: line, state: state) {
        if let newBlock = builder.createBlock(from: line, state: state, context: &context) {
          // Add the new block and let the builder process it
          context.current.append(newBlock as CodeNode<MarkdownNodeElement>)
          context.current = newBlock as CodeNode<MarkdownNodeElement>
          _ = builder.processLine(for: newBlock, line: line, state: state, context: &context)
          return
        }
      }
    }
    
    // If no builder handled the line, it's likely paragraph content
    // Find paragraph builder and delegate to it
    if let paragraphBuilder = builders.first(where: { $0.blockType == .paragraph }) {
      if let paragraph = paragraphBuilder.createBlock(from: line, state: state, context: &context) {
        context.current.append(paragraph as CodeNode<MarkdownNodeElement>)
        context.current = paragraph as CodeNode<MarkdownNodeElement>
        _ = paragraphBuilder.processLine(for: paragraph, line: line, state: state, context: &context)
      }
    }
  }
  
  /// Extract lines from tokens (utility method - no grammar logic)
  private func extractLines(from context: CodeConstructContext<Node, Token>) -> [[any CodeToken<MarkdownTokenElement>]] {
    var result: [[any CodeToken<MarkdownTokenElement>]] = []
    var line: [any CodeToken<MarkdownTokenElement>] = []
    var index = context.consuming
    
    while index < context.tokens.count {
      let token = context.tokens[index]
      
      if token.element == .eof {
        if !line.isEmpty {
          line.append(MarkdownToken(element: .newline, text: token.text, range: token.range))
          result.append(line)
        }
        result.append([])
        break
      } else if token.element == .newline {
        line.append(token)
        result.append(line)
        line = []
        index += 1
      } else {
        line.append(token)
        index += 1
      }
    }
    
    return result
  }
  
  /// Create the default set of Markdown block builders
  /// These are the standard builders that can be easily customized
  public static func createDefaultBuilders() -> [MarkdownBlockBuilderProtocol] {
    return [
      // Container blocks (processed first, higher priority = lower number)
      MarkdownBlockquoteBuilder(),
      
      // Leaf blocks (in rough priority order)  
      MarkdownThematicBreakBuilder(),
      
      // Fallback paragraph builder (lowest priority)
      MarkdownParagraphBuilder()
    ]
  }
}
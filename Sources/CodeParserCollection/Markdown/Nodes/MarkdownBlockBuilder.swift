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
  
  /// Implementation follows CommonMark algorithm but delegates all specific logic to builders
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }
    
    let lines = extractLines(from: context)
    guard !lines.isEmpty else { return false }
    
    // Process each line using CommonMark algorithm with builder delegation
    for line in lines {
      processLineWithCommonMarkAlgorithm(line, context: &context)
    }
    
    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Process a single line following CommonMark algorithm - delegates specific logic to builders
  private func processLineWithCommonMarkAlgorithm(
    _ line: [any CodeToken<MarkdownTokenElement>], 
    context: inout CodeConstructContext<Node, Token>
  ) {
    guard let state = context.state as? MarkdownConstructState else { return }
    
    // Reset line position
    state.position = 0
    state.isPartialLine = false
    
    // Step 1: Check continuation of open blocks (from innermost to outermost)
    let openBlocks = collectOpenBlocks(from: context.current)
    var continuedBlocks: [MarkdownNodeBase] = []
    
    for block in openBlocks.reversed() { // Process from innermost to outermost
      if let builder = findBuilderForBlock(block) {
        if builder.canContinue(block: block, line: line, state: state) {
          continuedBlocks.append(block)
          // Delegate line processing to the specific builder
          _ = builder.processLine(for: block, line: line, state: state, context: &context)
        } else {
          // This block cannot continue, so we stop here
          break
        }
      }
    }
    
    // Step 2: Close blocks that couldn't continue
    let lastContinuedBlock = continuedBlocks.last
    closeBlocksAfter(lastContinuedBlock, in: openBlocks, context: &context)
    
    // Step 3: Try to start new blocks (if line wasn't fully consumed by continuation)
    if !isLineFullyProcessed(line, state: state) {
      tryStartNewBlocks(line, context: &context, state: state)
    }
    
    // Step 4: If no new block was started, add content to the current open block
    if !isLineFullyProcessed(line, state: state) {
      addContentToCurrentBlock(line, context: &context, state: state)
    }
  }
  
  /// Collect all currently open blocks from current context up to root
  private func collectOpenBlocks(from current: CodeNode<MarkdownNodeElement>) -> [MarkdownNodeBase] {
    var blocks: [MarkdownNodeBase] = []
    var node: CodeNode<MarkdownNodeElement>? = current
    
    while let currentNode = node {
      if let markdownNode = currentNode as? MarkdownNodeBase {
        blocks.append(markdownNode)
      }
      node = currentNode.parent
    }
    
    return blocks
  }
  
  /// Find the builder responsible for a specific block type - pure delegation
  private func findBuilderForBlock(_ block: MarkdownNodeBase) -> MarkdownBlockBuilderProtocol? {
    return builders.first { builder in
      builder.blockType == block.element
    }
  }
  
  /// Close blocks that couldn't continue past the last continued block
  private func closeBlocksAfter(
    _ lastContinuedBlock: MarkdownNodeBase?,
    in openBlocks: [MarkdownNodeBase],
    context: inout CodeConstructContext<Node, Token>
  ) {
    guard let lastContinued = lastContinuedBlock else {
      // No blocks continued, close all except document
      if let documentBlock = openBlocks.first(where: { $0.element == .document }) {
        context.current = documentBlock as CodeNode<MarkdownNodeElement>
      }
      return
    }
    
    // Close blocks after the last continued one
    var foundLastContinued = false
    for block in openBlocks {
      if foundLastContinued {
        // This block should be closed - move context to its parent
        if let parent = (block as CodeNode<MarkdownNodeElement>).parent {
          context.current = parent
        }
      }
      if block === lastContinued {
        foundLastContinued = true
        context.current = block as CodeNode<MarkdownNodeElement>
      }
    }
  }
  
  /// Try to start new blocks with the current line - delegates to builders
  private func tryStartNewBlocks(
    _ line: [any CodeToken<MarkdownTokenElement>],
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) {
    for builder in builders {
      if builder.canStart(line: line, state: state) {
        if let newBlock = builder.createBlock(from: line, state: state, context: &context) {
          // Add the new block to current context and make it current
          context.current.append(newBlock as CodeNode<MarkdownNodeElement>)
          context.current = newBlock as CodeNode<MarkdownNodeElement>
          
          // Delegate line processing to the specific builder
          _ = builder.processLine(for: newBlock, line: line, state: state, context: &context)
          return
        }
      }
    }
  }
  
  /// Add content to the current open block (fallback to paragraph) - delegates to builders
  private func addContentToCurrentBlock(
    _ line: [any CodeToken<MarkdownTokenElement>],
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) {
    // Delegate to paragraph builder as fallback
    if let paragraphBuilder = builders.first(where: { $0.blockType == .paragraph }) {
      if context.current.element != .paragraph {
        if let paragraph = paragraphBuilder.createBlock(from: line, state: state, context: &context) {
          context.current.append(paragraph as CodeNode<MarkdownNodeElement>)
          context.current = paragraph as CodeNode<MarkdownNodeElement>
        }
      }
      
      // Delegate line processing to paragraph builder
      if let paragraph = context.current as? MarkdownNodeBase {
        _ = paragraphBuilder.processLine(for: paragraph, line: line, state: state, context: &context)
      }
    }
  }
  
  /// Check if the line has been fully processed
  private func isLineFullyProcessed(
    _ line: [any CodeToken<MarkdownTokenElement>],
    state: MarkdownConstructState
  ) -> Bool {
    return state.position >= line.count
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
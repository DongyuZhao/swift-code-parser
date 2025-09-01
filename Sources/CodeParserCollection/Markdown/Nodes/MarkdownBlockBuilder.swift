import CodeParserCore
import Foundation

/// MarkdownBlockBuilder that follows CommonMark parsing strategy
/// This implementation directly handles the CommonMark parsing algorithm:
/// 1. Check continuation of open blocks
/// 2. Close blocks that cannot continue
/// 3. Open new blocks as needed
/// 4. Add content to the current open block
/// 
/// The architecture separates concerns:
/// - This class handles the CommonMark parsing algorithm (continuation, closing, opening blocks)
/// - Individual builders handle block-specific logic without grammar specification
/// - The architecture remains fully pluggable for adding new block types
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  private let builders: [MarkdownBlockBuilderProtocol]
  
  /// Initialize with a custom set of builders
  public init(builders: [MarkdownBlockBuilderProtocol]) {
    // Sort builders by priority (lower number = higher priority)
    self.builders = builders.sorted { $0.priority < $1.priority }
  }
  
  /// Initialize with the standard set of CommonMark builders
  public convenience init() {
    self.init(builders: Self.createStandardBuilders())
  }
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }
    
    let lines = extractLines(from: context)
    guard !lines.isEmpty else { return false }
    
    for line in lines {
      processLine(line, context: &context)
    }
    
    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Process a single line following CommonMark algorithm
  private func processLine(
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
      if let builder = findBuilder(for: block) {
        if builder.canContinue(block: block, line: line, state: state) {
          continuedBlocks.append(block)
          // Process the line for this block
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
  
  /// Find the builder responsible for a specific block type
  private func findBuilder(for block: MarkdownNodeBase) -> MarkdownBlockBuilderProtocol? {
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
  
  /// Try to start new blocks with the current line
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
          
          // Process the line for the new block
          _ = builder.processLine(for: newBlock, line: line, state: state, context: &context)
          return
        }
      }
    }
  }
  
  /// Add content to the current open block (fallback to paragraph)
  private func addContentToCurrentBlock(
    _ line: [any CodeToken<MarkdownTokenElement>],
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) {
    // If we reach here, treat as paragraph content
    // This is a simplified fallback - in a real implementation, 
    // this should delegate to a paragraph builder
    if context.current.element != .paragraph {
      let dummyString = ""
      let range = dummyString.startIndex..<dummyString.endIndex
      let paragraph = ParagraphNode(range: range)
      context.current.append(paragraph)
      context.current = paragraph
    }
    
    // Add line content to paragraph (simplified)
    // In real implementation, this should be handled by paragraph builder
  }
  
  /// Check if the line has been fully processed
  private func isLineFullyProcessed(
    _ line: [any CodeToken<MarkdownTokenElement>],
    state: MarkdownConstructState
  ) -> Bool {
    return state.position >= line.count
  }
  
  /// Extract lines from tokens (same logic as original)
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
  
  /// Create the standard set of Markdown block builders
  /// This replaces the hardcoded rules from the old implementation
  private static func createStandardBuilders() -> [MarkdownBlockBuilderProtocol] {
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
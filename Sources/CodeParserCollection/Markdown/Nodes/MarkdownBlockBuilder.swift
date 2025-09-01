import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - The main CodeNodeBuilder implementation for Markdown
/// 
/// This class implements the CommonMark parsing algorithm:
/// 1. Line scanning: Process input line by line
/// 2. Block structure parsing: Use pluggable builders to recognize and create blocks
/// 3. Continuation/closing: Follow CommonMark rules for block continuation
/// 
/// Individual block builders are pluggable through MarkdownBlockBuilderProtocol
/// and contain no grammar-related logic - they only handle their specific block types.
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  private let blockBuilders: [MarkdownBlockBuilderProtocol]
  private var openBlocks: [any MarkdownBlockNode] = []
  private var currentLineNumber: Int = 0
  
  /// Initialize with custom block builders (pluggable architecture)
  public init(blockBuilders: [MarkdownBlockBuilderProtocol]) {
    self.blockBuilders = blockBuilders
  }
  
  /// Initialize with default block builders
  public convenience init() {
    self.init(blockBuilders: Self.createDefaultBuilders())
  }
  
  /// Main CodeNodeBuilder implementation - processes tokens using CommonMark algorithm
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    
    // For now, simplify: process all remaining tokens as a single block
    let remainingTokens = Array(context.tokens[context.consuming...])
    guard !remainingTokens.isEmpty else { return false }
    
    // Convert to a single line for processing
    let line = MarkdownLine(tokens: remainingTokens, lineNumber: 0)
    
    // Try to create a block with one of the builders
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        if let newBlock = builder.createBlock(from: line) {
          // Add the block to context and consume all tokens
          if let markdownNode = newBlock as? MarkdownNodeBase {
            context.current.append(markdownNode)
          }
          context.consuming = context.tokens.count // Consume all tokens
          
          // Close the block
          builder.closeBlock(block: newBlock)
          return true
        }
      }
    }
    
    return false
  }
  
  /// Extract lines from token stream starting at given position
  private func extractLines(from tokens: [any CodeToken<MarkdownTokenElement>], startingAt: Int) -> [MarkdownLine] {
    var lines: [MarkdownLine] = []
    var currentLineTokens: [any CodeToken<MarkdownTokenElement>] = []
    var index = startingAt
    
    while index < tokens.count {
      let token = tokens[index]
      currentLineTokens.append(token)
      
      // End of line or end of input
      if token.element == .newline || token.element == .eof || index == tokens.count - 1 {
        let line = MarkdownLine(tokens: currentLineTokens, lineNumber: lines.count)
        lines.append(line)
        currentLineTokens = []
        
        if token.element == .eof {
          break
        }
      }
      
      index += 1
    }
    
    // Add any remaining tokens as final line
    if !currentLineTokens.isEmpty {
      let line = MarkdownLine(tokens: currentLineTokens, lineNumber: lines.count)
      lines.append(line)
    }
    
    return lines
  }
  
  /// Phase 1: Check which open blocks can continue with the current line
  private func checkBlockContinuation(line: MarkdownLine) {
    var continuableBlocks: [any MarkdownBlockNode] = []
    
    // Check from innermost to outermost
    for block in openBlocks.reversed() {
      // Find the builder for this block type
      let builder = blockBuilders.first { $0.canContinue(block: block, line: line) }
      
      if builder != nil {
        // This block and all its parents can continue
        continuableBlocks.insert(block, at: 0)
        // Find all parent blocks
        for parentBlock in openBlocks {
          if parentBlock === block { break }
          continuableBlocks.insert(parentBlock, at: 0)
        }
        break
      }
    }
    
    openBlocks = continuableBlocks
  }
  
  /// Phase 2: Close blocks that cannot continue (already handled in checkBlockContinuation)
  private func closeUnmatchedBlocks() {
    // Block closing is handled implicitly by removing them from openBlocks
    // The actual closing logic will be called in closeAllBlocks()
  }
  
  /// Phase 3: Try to open new blocks with the current line
  private func openNewBlocks(line: MarkdownLine) {
    // Try each builder to see if it can start a new block
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        if let newBlock = builder.createBlock(from: line) {
          openBlocks.append(newBlock)
          return // Only open one new block per line
        }
      }
    }
  }
  
  /// Phase 4: Process line content for the current block
  private func processLineForBlock(block: any MarkdownBlockNode, line: MarkdownLine) {
    // Find the appropriate builder for this block
    for builder in blockBuilders {
      if builder.canContinue(block: block, line: line) {
        _ = builder.processLine(block: block, line: line)
        return
      }
    }
  }
  
  /// Close all open blocks and perform post-processing
  private func closeAllBlocks() {
    for block in openBlocks {
      // Find the appropriate builder and close the block
      for builder in blockBuilders {
        // We can use canContinue as a proxy for "this builder handles this block type"
        let dummyLine = MarkdownLine(tokens: [], lineNumber: 0)
        if builder.canContinue(block: block, line: dummyLine) {
          builder.closeBlock(block: block)
          break
        }
      }
    }
  }
  
  /// Add all closed blocks to the context
  private func addBlocksToContext(context: inout CodeConstructContext<Node, Token>) {
    for block in openBlocks {
      if let markdownNode = block as? MarkdownNodeBase {
        context.current.append(markdownNode)
      }
    }
    openBlocks.removeAll()
  }
  
  /// Create default set of block builders
  public static func createDefaultBuilders() -> [MarkdownBlockBuilderProtocol] {
    return [
      // Order matters: more specific builders should come first
      MarkdownIndentedCodeBlockBuilder(),
      MarkdownParagraphBuilder()
    ]
  }
}
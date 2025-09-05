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
  private var closedBlocks: [MarkdownNodeBase] = []
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
    
    // Extract lines from remaining tokens
    let remainingTokens = Array(context.tokens[context.consuming...])
    guard !remainingTokens.isEmpty else { return false }

    let lines = extractLines(from: remainingTokens, startingAt: 0)
    guard !lines.isEmpty else { return false }
    
    // Process each line using CommonMark algorithm with setext heading support
    var lineIndex = 0
    while lineIndex < lines.count {
      let line = lines[lineIndex]
      currentLineNumber = line.lineNumber
      
      // Check for setext headings (requires looking ahead)
      if lineIndex + 1 < lines.count {
        let nextLine = lines[lineIndex + 1]
        let (isUnderline, level) = MarkdownSetextHeadingBuilder.isSetextUnderline(nextLine, for: line)
        
        if isUnderline {
          // Create setext heading and skip the underline
          if let setextHeading = MarkdownSetextHeadingBuilder.createSetextHeading(from: line, level: level) {
            closedBlocks.append(setextHeading)
            lineIndex += 2 // Skip both the text line and underline
            continue
          }
        }
      }
      
      // Normal CommonMark processing
      // Phase 1: Check continuation of open blocks (from innermost to outermost)
      let lineConsumed = checkBlockContinuation(line: line)
      
      // If the line was consumed by an existing block (including closing), don't try to start new blocks
      if lineConsumed {
        lineIndex += 1
        continue
      }
      
      // Phase 2: Close blocks that cannot continue (handled in checkBlockContinuation)
      closeUnmatchedBlocks()
      
      // Phase 3: Try to open new blocks with current line  
      // Check if any new block can interrupt the current block
      if canNewBlockInterrupt(line: line) {
        // Close current blocks that can be interrupted
        closeInterruptedBlocks(line: line)
        openNewBlocks(line: line)
      } else if openBlocks.isEmpty || !canCurrentBlockContinue(line: line) {
        openNewBlocks(line: line)
      }
      
      // Phase 4: Process line content for current block (if we opened a new block)
      if let currentBlock = openBlocks.last {
        processLineForBlock(block: currentBlock, line: line)
      }
      
      lineIndex += 1
    }
    
    // Close all remaining open blocks and add them to context
    closeAllBlocks()
    addBlocksToContext(context: &context)
    
    // Consume all processed tokens
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Check if a new block can interrupt the current open blocks
  private func canNewBlockInterrupt(line: MarkdownLine) -> Bool {
    // ATX headings and thematic breaks can interrupt paragraphs
    if !openBlocks.isEmpty {
      // Check if any block builder can start a new block with this line
      for builder in blockBuilders {
        if builder.canStart(line: line) {
          // Some block types can interrupt others
          if (builder is MarkdownATXHeadingBuilder) ||
             (builder is MarkdownThematicBreakBuilder) ||
             (builder is MarkdownFencedCodeBlockBuilder) ||
             (builder is MarkdownBlockquoteBuilder) ||
             (builder is MarkdownListItemBuilder) {
            return true
          }
        }
      }
    }
    
    return false
  }
  
  /// Close blocks that can be interrupted by new blocks
  private func closeInterruptedBlocks(line: MarkdownLine) {
    // For now, only paragraphs can be interrupted
    var blocksToClose: [any MarkdownBlockNode] = []
    
    for block in openBlocks {
      if block.blockType == "paragraph" {
        blocksToClose.append(block)
      }
    }
    
    for block in blocksToClose {
      closeBlock(block: block)
      addBlockToContext(block: block)
      if let index = openBlocks.firstIndex(where: { $0 === block }) {
        openBlocks.remove(at: index)
      }
    }
  }
  
  /// Check if the current block can continue with the given line
  private func canCurrentBlockContinue(line: MarkdownLine) -> Bool {
    guard let currentBlock = openBlocks.last else { return false }
    
    // Find the builder for the current block
    for builder in blockBuilders {
      if builder.canContinue(block: currentBlock, line: line) {
        return true
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
      
      // Add the token to current line
      currentLineTokens.append(token)
      
      // Check if this token ends the line
      if token.element == .newline || token.element == .eof {
        let line = MarkdownLine(tokens: currentLineTokens, lineNumber: lines.count)
        lines.append(line)
        currentLineTokens = []
        
        if token.element == .eof {
          break
        }
      }
      
      index += 1
    }
    
    // Add any remaining tokens as final line if needed
    if !currentLineTokens.isEmpty {
      let line = MarkdownLine(tokens: currentLineTokens, lineNumber: lines.count)
      lines.append(line)
    }
    
    return lines
  }
  
  /// Check continuation of open blocks and process line content
  /// Returns true if the line was consumed by an existing block (including for closing)
  private func checkBlockContinuation(line: MarkdownLine) -> Bool {
    var continuableBlocks: [any MarkdownBlockNode] = []
    var lineConsumed = false
    
    // For blank lines, most blocks (like paragraphs) cannot continue
    if line.isBlank {
      // Close and finalize all open blocks before clearing them
      for block in openBlocks {
        closeBlock(block: block)
        addBlockToContext(block: block)
      }
      // Empty the open blocks - blank lines close most block types
      openBlocks = []
      return true // Blank lines are always consumed
    }
    
    // Check from innermost to outermost
    for block in openBlocks.reversed() {
      // Find the builder for this block type
      if let builder = blockBuilders.first(where: { $0.canContinue(block: block, line: line) }) {
        // This block and all its parents can continue
        continuableBlocks.insert(block, at: 0)
        // Find all parent blocks
        for parentBlock in openBlocks {
          if parentBlock === block { break }
          continuableBlocks.insert(parentBlock, at: 0)
        }
        
        // Process the line for this block
        _ = builder.processLine(block: block, line: line)
        lineConsumed = true
        break
      } else {
        // Check if this builder should close the block with this line
        if let builder = blockBuilders.first(where: { builder in
          // For fenced code blocks, check if this line closes it
          if block.blockType == "fenced_code_block" && builder is MarkdownFencedCodeBlockBuilder {
            let canCont = builder.canContinue(block: block, line: line)
            if !canCont {
              // Process the closing line
              _ = builder.processLine(block: block, line: line)
              lineConsumed = true
              return true
            }
          }
          return false
        }) {
          break
        }
      }
    }
    
    // Close blocks that couldn't continue
    for block in openBlocks {
      if !continuableBlocks.contains(where: { $0 === block }) {
        closeBlock(block: block)
        addBlockToContext(block: block)
      }
    }
    
    openBlocks = continuableBlocks
    return lineConsumed
  }
  
  /// Phase 2: Close blocks that cannot continue (already handled in checkBlockContinuation)
  private func closeUnmatchedBlocks() {
    // Block closing is handled implicitly by removing them from openBlocks
    // The actual closing logic will be called in closeAllBlocks()
  }
  
  /// Phase 3: Try to open new blocks with the current line
  private func openNewBlocks(line: MarkdownLine) {
    // Don't try to open new blocks on blank lines
    if line.isBlank {
      return
    }
    
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
  
  /// Close and finalize a single block
  private func closeBlock(block: any MarkdownBlockNode) {
    // Find the appropriate builder and close the block
    for builder in blockBuilders {
      // Use block type comparison instead of canContinue for closing
      if (block.blockType == "paragraph" && builder is MarkdownParagraphBuilder) ||
         (block.blockType == "code_block" && builder is MarkdownIndentedCodeBlockBuilder) ||
         (block.blockType == "heading" && builder is MarkdownATXHeadingBuilder) ||
         (block.blockType == "thematic_break" && builder is MarkdownThematicBreakBuilder) ||
         (block.blockType == "blockquote" && builder is MarkdownBlockquoteBuilder) ||
         (block.blockType == "fenced_code_block" && builder is MarkdownFencedCodeBlockBuilder) ||
         (block.blockType == "list_item" && builder is MarkdownListItemBuilder) {
        builder.closeBlock(block: block)
        break
      }
    }
  }
  
  /// Add a single block to the context
  private func addBlockToContext(block: any MarkdownBlockNode) {
    if let markdownNode = block as? MarkdownNodeBase {
      // We need access to the context here, but this method doesn't have it
      // Let's store blocks and add them later
      self.closedBlocks.append(markdownNode)
    }
  }

  /// Close all open blocks and perform post-processing
  private func closeAllBlocks() {
    for block in openBlocks {
      closeBlock(block: block)
    }
  }
  
  /// Add all closed blocks to the context
  private func addBlocksToContext(context: inout CodeConstructContext<Node, Token>) {
    // Add previously closed blocks
    for block in closedBlocks {
      context.current.append(block)
    }
    closedBlocks.removeAll()
    
    // Add any remaining open blocks
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
      MarkdownATXHeadingBuilder(),
      MarkdownThematicBreakBuilder(),
      MarkdownFencedCodeBlockBuilder(),
      MarkdownListItemBuilder(),
      MarkdownBlockquoteBuilder(),
      MarkdownIndentedCodeBlockBuilder(),
      MarkdownParagraphBuilder() // Paragraph should be last as it's the fallback
    ]
  }
}
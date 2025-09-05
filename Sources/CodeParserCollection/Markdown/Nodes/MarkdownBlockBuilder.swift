import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - The main CodeNodeBuilder implementation for Markdown
/// 
/// This class implements the CommonMark parsing algorithm using context.current (AST) as the single source of truth:
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

    let lines = extractLines(from: remainingTokens)
    guard !lines.isEmpty else { return false }
    
    // Process each line using CommonMark algorithm with setext heading support
    var lineIndex = 0
    while lineIndex < lines.count {
      let line = lines[lineIndex]
      
      // Check for setext headings (requires looking ahead)
      if lineIndex + 1 < lines.count {
        let nextLine = lines[lineIndex + 1]
        let (isUnderline, level) = MarkdownSetextHeadingBuilder.isSetextUnderline(nextLine, for: line)
        
        if isUnderline {
          // Create setext heading and skip the underline
          if let setextHeading = MarkdownSetextHeadingBuilder.createSetextHeading(from: line, level: level) {
            context.current.append(setextHeading)
            lineIndex += 2 // Skip both the text line and underline
            continue
          }
        }
      }
      
      // Normal CommonMark processing
      // Phase 1: Check continuation of open blocks (from innermost to outermost)
      let lineConsumed = checkBlockContinuation(line: line, context: &context)
      
      // If the line was consumed by an existing block (including closing), don't try to start new blocks
      if lineConsumed {
        lineIndex += 1
        continue
      }
      
      // Phase 2: Close blocks that cannot continue (handled in checkBlockContinuation)
      // Phase 3: Try to open new blocks with current line  
      // Check if any new block can interrupt the current block
      if canNewBlockInterrupt(line: line, context: context) {
        // Close current blocks that can be interrupted
        closeInterruptedBlocks(line: line, context: &context)
        openNewBlocks(line: line, context: &context)
      } else if !hasOpenBlocks(context: context) || !canCurrentBlockContinue(line: line, context: context) {
        openNewBlocks(line: line, context: &context)
      }
      
      lineIndex += 1
    }
    
    // Close all remaining open blocks 
    closeAllBlocks(context: &context)
    
    // Consume all processed tokens
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Get the current open block from AST (last incomplete block)
  private func getCurrentOpenBlock(context: CodeConstructContext<Node, Token>) -> (any MarkdownBlockNode)? {
    // Walk the AST to find the deepest incomplete block
    var current = context.current
    while let lastChild = current.children.last as? MarkdownNodeBase {
      // Check if this child is a block that can continue (incomplete)
      if let blockNode = lastChild as? any MarkdownBlockNode {
        // Check if this block is still open/incomplete
        if canBlockContinue(blockNode) {
          return blockNode
        }
      }
      current = lastChild
    }
    return nil
  }
  
  /// Check if there are open blocks in the AST
  private func hasOpenBlocks(context: CodeConstructContext<Node, Token>) -> Bool {
    return getCurrentOpenBlock(context: context) != nil
  }
  
  /// Check if a block can still continue (is incomplete)
  private func canBlockContinue(_ block: any MarkdownBlockNode) -> Bool {
    // Most blocks can continue until explicitly closed
    // Specific builders will handle their own closing logic
    return true // Default assumption - builders handle closing
  }
  
  /// Check if a new block can interrupt the current open blocks
  private func canNewBlockInterrupt(line: MarkdownLine, context: CodeConstructContext<Node, Token>) -> Bool {
    // ATX headings and thematic breaks can interrupt paragraphs
    guard hasOpenBlocks(context: context) else { return false }
    
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
    
    return false
  }
  
  /// Close blocks that can be interrupted by new blocks
  private func closeInterruptedBlocks(line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) {
    // For now, only paragraphs can be interrupted
    if let currentBlock = getCurrentOpenBlock(context: context) {
      if currentBlock.blockType == "paragraph" {
        closeBlock(block: currentBlock)
      }
    }
  }
  
  /// Check if the current block can continue with the given line
  private func canCurrentBlockContinue(line: MarkdownLine, context: CodeConstructContext<Node, Token>) -> Bool {
    guard let currentBlock = getCurrentOpenBlock(context: context) else { return false }
    
    // Find the builder for the current block
    for builder in blockBuilders {
      if builder.canContinue(block: currentBlock, line: line) {
        return true
      }
    }
    return false
  }

  /// Extract lines from token stream
  private func extractLines(from tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownLine] {
    var lines: [MarkdownLine] = []
    var currentLineTokens: [any CodeToken<MarkdownTokenElement>] = []
    var index = 0
    
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
  private func checkBlockContinuation(line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) -> Bool {
    // For blank lines, most blocks (like paragraphs) cannot continue
    if line.isBlank {
      // Close all open blocks - blank lines close most block types
      closeAllBlocks(context: &context)
      return true // Blank lines are always consumed
    }
    
    // Check the current open block
    guard let currentBlock = getCurrentOpenBlock(context: context) else { return false }
    
    // Find the builder for this block type
    if let builder = blockBuilders.first(where: { $0.canContinue(block: currentBlock, line: line) }) {
      // This block can continue - process the line
      _ = builder.processLine(block: currentBlock, line: line)
      return true
    } else {
      // Check if this builder should close the block with this line
      if let builder = blockBuilders.first(where: { builder in
        // For fenced code blocks, check if this line closes it
        if currentBlock.blockType == "fenced_code_block" && builder is MarkdownFencedCodeBlockBuilder {
          let canCont = builder.canContinue(block: currentBlock, line: line)
          if !canCont {
            // Process the closing line
            _ = builder.processLine(block: currentBlock, line: line)
            closeBlock(block: currentBlock)
            return true
          }
        }
        return false
      }) {
        return true
      }
      
      // Block cannot continue - close it
      closeBlock(block: currentBlock)
      return false
    }
  }
  
  /// Try to open new blocks with the current line
  private func openNewBlocks(line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) {
    // Don't try to open new blocks on blank lines
    if line.isBlank {
      return
    }
    
    // Try each builder to see if it can start a new block
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        if let newBlock = builder.createBlock(from: line) {
          // Add the new block to the AST
          context.current.append(newBlock as! MarkdownNodeBase)
          
          // Process the line that opened this block
          _ = builder.processLine(block: newBlock, line: line)
          return // Only open one new block per line
        }
      }
    }
  }
  
  /// Process line content for the current block
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

  /// Close all open blocks in the AST
  private func closeAllBlocks(context: inout CodeConstructContext<Node, Token>) {
    // Find all open blocks in the AST and close them
    var blocksToClose: [any MarkdownBlockNode] = []
    collectOpenBlocks(node: context.current, into: &blocksToClose)
    
    for block in blocksToClose {
      closeBlock(block: block)
    }
  }
  
  /// Recursively collect all open blocks from the AST
  private func collectOpenBlocks(node: CodeNode<MarkdownNodeElement>, into blocks: inout [any MarkdownBlockNode]) {
    for child in node.children {
      if let markdownChild = child as? MarkdownNodeBase {
        if let blockNode = markdownChild as? any MarkdownBlockNode {
          if canBlockContinue(blockNode) {
            blocks.append(blockNode)
          }
        }
        // Recursively check children
        collectOpenBlocks(node: markdownChild, into: &blocks)
      }
    }
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
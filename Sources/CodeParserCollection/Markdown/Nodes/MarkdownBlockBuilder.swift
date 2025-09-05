import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - The main CodeNodeBuilder implementation for Markdown
/// 
/// This class processes Markdown tokens using the AST (context.current) as the editable single source of truth.
/// It directly consumes tokens and modifies the AST structure, delegating block-specific logic to pluggable builders.
/// 
/// Individual block builders are pluggable through MarkdownBlockBuilderProtocol and contain no grammar-related logic.
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
  
  /// Main CodeNodeBuilder implementation - processes tokens and directly edits AST
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    
    // Process tokens line by line, directly editing the AST
    while context.consuming < context.tokens.count {
      // Extract one line of tokens starting from current position
      let lineTokens = extractNextLine(from: &context)
      guard !lineTokens.isEmpty else { break }
      
      // Create a line representation
      let line = MarkdownLine(tokens: lineTokens, lineNumber: getCurrentLineNumber(context))
      
      // Process this line by directly editing the AST
      processLineIntoAST(line, context: &context)
    }
    
    // Finalize all blocks (important for blocks like blockquotes that need recursive parsing)
    finalizeBlocksInAST(node: context.current)
    
    return true
  }
  
  /// Extract the next line of tokens from the current position
  private func extractNextLine(from context: inout CodeConstructContext<Node, Token>) -> [any CodeToken<MarkdownTokenElement>] {
    var lineTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    // Collect tokens until we hit a newline or EOF
    while context.consuming < context.tokens.count {
      let token = context.tokens[context.consuming]
      lineTokens.append(token)
      context.consuming += 1
      
      // Stop at newline or EOF (include them in the line)
      if token.element == .newline || token.element == .eof {
        break
      }
    }
    
    return lineTokens
  }
  
  /// Get current line number (approximate)
  private func getCurrentLineNumber(_ context: CodeConstructContext<Node, Token>) -> Int {
    // Count newlines up to current position
    var lineNumber = 0
    for i in 0..<context.consuming {
      if context.tokens[i].element == .newline {
        lineNumber += 1
      }
    }
    return lineNumber
  }
  
  /// Process a line by determining what block it belongs to and directly editing the AST
  private func processLineIntoAST(_ line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) {
    // Skip blank lines - they typically close blocks or are ignored
    if line.isBlank {
      closeOpenBlocks(context: &context)
      return
    }
    
    // Store the current line in state for builders to process
    guard var state = context.state as? MarkdownConstructState else { return }
    state.tokens = line.tokens
    state.currentLineProcessed = false
    
    // Process with yield-back pattern: keep processing until line is fully consumed
    var iterations = 0
    let maxIterations = 10
    while !state.currentLineProcessed && !state.tokens.isEmpty && iterations < maxIterations {
      iterations += 1
      let currentLine = MarkdownLine(tokens: state.tokens, lineNumber: line.lineNumber)
      state.currentLineProcessed = true // Will be set to false if a builder yields back
      
      // Store tokens count to detect infinite loops
      let tokensBeforeProcessing = state.tokens.count
      
      // FIRST: Check if this line can start an interrupting block type
      // If so, create it immediately (this handles thematic breaks, headings, etc.)
      if canLineInterruptExistingBlocks(currentLine) {
        closeInterruptibleBlocks(context: &context)
        let newBlockCreated = tryCreateNewBlockWithLine(currentLine, context: &context, state: &state)
        
        // If a container block was created and tokens were yielded back, process them in the container's context
        if !state.currentLineProcessed && newBlockCreated != nil && isContainerBlock(newBlockCreated!) {
          processYieldedTokensInContainer(newBlockCreated!, state: &state, lineNumber: line.lineNumber)
        }
      } else {
        // SECOND: Check if any existing block can continue with current tokens
        if let continuingBlock = findBlockThatCanContinue(currentLine, in: context.current) {
          // Check if continuation is valid before processing
          if canContinueBlock(continuingBlock, with: currentLine) {
            processLineWithBuilder(currentLine, for: continuingBlock, state: &state)
            
            // If this is a container block and tokens were yielded back, process them in the container's context
            if !state.currentLineProcessed && isContainerBlock(continuingBlock) {
              processYieldedTokensInContainer(continuingBlock, state: &state, lineNumber: line.lineNumber)
            }
          } else {
            // Block cannot continue, close it and try new block
            closeBlock(continuingBlock, context: &context)
            _ = tryCreateNewBlockWithLine(currentLine, context: &context, state: &state)
          }
        } else {
          // No continuing block, try new block
          let newBlockCreated = tryCreateNewBlockWithLine(currentLine, context: &context, state: &state)
          
          // If a container block was created and tokens were yielded back, process them in the container's context
          if !state.currentLineProcessed && newBlockCreated != nil && isContainerBlock(newBlockCreated!) {
            processYieldedTokensInContainer(newBlockCreated!, state: &state, lineNumber: line.lineNumber)
          }
        }
      }
      
      // Safety check: if tokens weren't consumed and line isn't processed, break to prevent infinite loop
      if state.tokens.count == tokensBeforeProcessing && !state.currentLineProcessed {
        state.currentLineProcessed = true // Force completion to avoid infinite loop
        break
      }
    }
    
    // Update context state
    context.state = state
  }
  
  /// Find an existing block in the AST that can continue with this line
  private func findBlockThatCanContinue(_ line: MarkdownLine, in node: CodeNode<MarkdownNodeElement>) -> (any MarkdownBlockNode)? {
    // In CommonMark, only the most recently added (leaf) block can be continued
    // Check only the last child first, then recursively check its children
    if let lastChild = node.children.last as? MarkdownNodeBase {
      if let blockNode = lastChild as? any MarkdownBlockNode {
        // Check if any builder can continue this block
        for builder in blockBuilders {
          if builder.canContinue(block: blockNode, line: line) {
            return blockNode
          }
        }
      }
      
      // Recursively check the last child's children (for open container blocks)
      if let nestedBlock = findBlockThatCanContinue(line, in: lastChild) {
        return nestedBlock
      }
    }
    
    return nil
  }
  
  /// Check if this line can interrupt existing blocks
  private func canLineInterruptExistingBlocks(_ line: MarkdownLine) -> Bool {
    // Check if any builder can start an interrupting block type
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        let builderType = type(of: builder)
        if builderType is MarkdownATXHeadingBuilder.Type ||
           builderType is MarkdownSetextHeadingBuilder.Type ||
           builderType is MarkdownThematicBreakBuilder.Type ||
           builderType is MarkdownFencedCodeBlockBuilder.Type {
          return true
        }
      }
    }
    return false
  }
  
  /// Close blocks that can be interrupted
  private func closeInterruptibleBlocks(context: inout CodeConstructContext<Node, Token>) {
    // For now, close paragraphs when interrupted
    // In the future, this could be more sophisticated
    closeOpenBlocks(context: &context)
  }
  
  /// Close all open blocks
  private func closeOpenBlocks(context: inout CodeConstructContext<Node, Token>) {
    // Walk the AST and finalize any blocks that need closing
    finalizeBlocksInAST(node: context.current)
  }
  
  /// Recursively finalize blocks in the AST
  private func finalizeBlocksInAST(node: CodeNode<MarkdownNodeElement>) {
    for child in node.children {
      if let markdownChild = child as? MarkdownNodeBase {
        if let blockNode = markdownChild as? any MarkdownBlockNode {
          // Close this block
          for builder in blockBuilders {
            if canBuilderHandle(builder, blockType: blockNode.blockType) {
              builder.closeBlock(block: blockNode)
              break
            }
          }
        }
        // Recursively process children
        finalizeBlocksInAST(node: markdownChild)
      }
    }
  }
  
  /// Try to create a new block for this line
  private func tryCreateNewBlock(for line: MarkdownLine) -> (any MarkdownBlockNode)? {
    // Try each builder in order (most specific first)
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        return builder.createBlock(from: line)
      }
    }
    return nil
  }
  
  /// Check if a block can continue with the given line
  private func canContinueBlock(_ block: any MarkdownBlockNode, with line: MarkdownLine) -> Bool {
    for builder in blockBuilders {
      if builder.canContinue(block: block, line: line) {
        return true
      }
    }
    return false
  }
  
  /// Process a line with the appropriate builder for the given block
  private func processLineWithBuilder(_ line: MarkdownLine, for block: any MarkdownBlockNode, state: inout MarkdownConstructState) {
    for builder in blockBuilders {
      if builder.canContinue(block: block, line: line) {
        _ = builder.processLine(block: block, line: line, state: &state)
        return
      }
    }
  }
  
  /// Try to create a new block with the current line
  private func tryCreateNewBlockWithLine(_ line: MarkdownLine, context: inout CodeConstructContext<Node, Token>, state: inout MarkdownConstructState) -> (any MarkdownBlockNode)? {
    // Try each plugged builder to see if it can start a new block
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        if let newBlock = builder.createBlock(from: line) {
          // Determine where to add the new block based on current context
          let targetNode = findTargetNodeForNewBlock(in: context.current)
          targetNode.append(newBlock as! MarkdownNodeBase)
          
          // Process the opening line with the builder
          _ = builder.processLine(block: newBlock, line: line, state: &state)
          return newBlock
        }
      }
    }
    
    // Fallback to paragraph if no builder can handle the line
    createAndProcessParagraph(for: line, context: &context, state: &state)
    return nil
  }
  
  /// Close a specific block
  private func closeBlock(_ block: any MarkdownBlockNode, context: inout CodeConstructContext<Node, Token>) {
    for builder in blockBuilders {
      if canBuilderHandle(builder, blockType: block.blockType) {
        builder.closeBlock(block: block)
        return
      }
    }
  }
  
  /// Process yielded-back tokens within a container block's context
  private func processYieldedTokensInContainer(_ containerBlock: any MarkdownBlockNode, state: inout MarkdownConstructState, lineNumber: Int) {
    guard !state.tokens.isEmpty else { 
      state.currentLineProcessed = true
      return 
    }
    
    // Create a sub-context where context.current points to the container block
    let containerNode = containerBlock as! MarkdownNodeBase
    
    // Process the remaining tokens as a new line within the container
    let containerLine = MarkdownLine(tokens: state.tokens, lineNumber: lineNumber)
    
    // First, check if any existing block within the container can continue
    if let continuingBlock = findBlockThatCanContinue(containerLine, in: containerNode) {
      if canContinueBlock(continuingBlock, with: containerLine) {
        processLineWithBuilder(containerLine, for: continuingBlock, state: &state)
        state.currentLineProcessed = true
        return
      }
    }
    
    // Try each plugged builder to see if it can start a new block within the container
    for builder in blockBuilders {
      if builder.canStart(line: containerLine) {
        if let newBlock = builder.createBlock(from: containerLine) {
          // Add the new block to the container
          containerNode.append(newBlock as! MarkdownNodeBase)
          
          // Process the opening line with the builder
          _ = builder.processLine(block: newBlock, line: containerLine, state: &state)
          
          // Mark as processed since we handled the yielded tokens
          state.currentLineProcessed = true
          return
        }
      }
    }
    
    // Fallback to paragraph within the container
    let paragraph = createParagraphBlock()
    containerNode.append(paragraph as! MarkdownNodeBase)
    
    // Process the line into the paragraph
    for builder in blockBuilders {
      if builder is MarkdownParagraphBuilder {
        _ = builder.processLine(block: paragraph, line: containerLine, state: &state)
        state.currentLineProcessed = true
        return
      }
    }
    
    // Ensure we mark as processed
    state.currentLineProcessed = true
  }
  /// This ensures blocks are added in the correct container context
  private func findTargetNodeForNewBlock(in node: CodeNode<MarkdownNodeElement>) -> CodeNode<MarkdownNodeElement> {
    // For now, find the deepest open container block or return the root
    if let lastChild = node.children.last as? MarkdownNodeBase {
      if let blockNode = lastChild as? any MarkdownBlockNode {
        if isContainerBlock(blockNode) {
          // This is a container block, add content to it
          return lastChild
        }
      }
    }
    
    // Default to the current node
    return node
  }
  
  /// Create and process a paragraph for this line
  private func createAndProcessParagraph(for line: MarkdownLine, context: inout CodeConstructContext<Node, Token>, state: inout MarkdownConstructState) {
    // Create a new paragraph
    let paragraph = createParagraphBlock()
    
    // Add paragraph to the appropriate target node
    let targetNode = findTargetNodeForNewBlock(in: context.current)
    targetNode.append(paragraph as! MarkdownNodeBase)
    
    // Process the line into the paragraph
    for builder in blockBuilders {
      if builder is MarkdownParagraphBuilder {
        _ = builder.processLine(block: paragraph, line: line, state: &state)
        return
      }
    }
  }
  
  /// Create a default paragraph block
  private func createParagraphBlock() -> any MarkdownBlockNode {
    // Use a dummy range - the range will be updated when content is added
    let dummyString = ""
    let range = dummyString.startIndex..<dummyString.endIndex
    return ParagraphNode(range: range)
  }
  
  /// Check if a block is a container block that can contain other blocks
  private func isContainerBlock(_ block: any MarkdownBlockNode) -> Bool {
    switch block.blockType {
    case "blockquote": return true
    case "list_item": return true
    default: return false
    }
  }
  
  /// Check if a builder can handle a specific block type
  private func canBuilderHandle(_ builder: MarkdownBlockBuilderProtocol, blockType: String) -> Bool {
    switch blockType {
    case "paragraph": return builder is MarkdownParagraphBuilder
    case "heading": return builder is MarkdownATXHeadingBuilder || builder is MarkdownSetextHeadingBuilder
    case "thematic_break": return builder is MarkdownThematicBreakBuilder
    case "code_block": return builder is MarkdownIndentedCodeBlockBuilder
    case "fenced_code_block": return builder is MarkdownFencedCodeBlockBuilder
    case "blockquote": return builder is MarkdownBlockquoteBuilder
    case "list_item": return builder is MarkdownListItemBuilder
    default: return false
    }
  }
  
  /// Create default set of block builders
  public static func createDefaultBuilders() -> [MarkdownBlockBuilderProtocol] {
    return [
      // Order matters: more specific builders should come first
      MarkdownSetextHeadingBuilder(), // Must come before thematic break to handle "---" after text
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
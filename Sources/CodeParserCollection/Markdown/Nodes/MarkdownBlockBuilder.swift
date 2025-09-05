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
    if var state = context.state as? MarkdownConstructState {
      state.tokens = line.tokens
      state.currentLineProcessed = false
      
      // Keep processing until the line is fully processed
      while !state.currentLineProcessed && !state.tokens.isEmpty {
        state.currentLineProcessed = true // Will be set to false if a builder yields back
        
        // Check if any existing block can continue with current tokens
        let currentLine = MarkdownLine(tokens: state.tokens, lineNumber: line.lineNumber)
        if let continuingBlock = findBlockThatCanContinue(currentLine, in: context.current) {
          // Let the appropriate builder process tokens and potentially modify state
          processContinuationLine(currentLine, for: continuingBlock, state: &state)
        } else {
          // Check if this line should interrupt any existing blocks
          if canLineInterruptExistingBlocks(MarkdownLine(tokens: state.tokens, lineNumber: line.lineNumber)) {
            closeInterruptibleBlocks(context: &context)
          }
          
          // Try to start a new block with current tokens
          let currentLine = MarkdownLine(tokens: state.tokens, lineNumber: line.lineNumber)
          if let newBlock = tryCreateNewBlock(for: currentLine) {
            // Add the new block to the AST
            context.current.append(newBlock as! MarkdownNodeBase)
            
            // If this is a container block (like blockquote), update context to point to it
            let wasContainer = isContainerBlock(newBlock)
            if wasContainer {
              context.current = newBlock as! MarkdownNodeBase
            }
            
            // Process the opening line and potentially modify state
            processOpeningLine(currentLine, for: newBlock, state: &state)
            
            // If we made current point to a container and processing isn't complete,
            // continue processing within that container
            if wasContainer && !state.currentLineProcessed {
              continue
            }
          } else {
            // Fallback to paragraph
            createAndProcessParagraph(for: currentLine, context: &context, state: &state)
            break // Paragraph consumes everything
          }
        }
      }
      
      // Update context state
      context.state = state
    }
  }
  
  /// Find an existing block in the AST that can continue with this line
  private func findBlockThatCanContinue(_ line: MarkdownLine, in node: CodeNode<MarkdownNodeElement>) -> (any MarkdownBlockNode)? {
    // Look at the last child first (most recent block)
    if let lastChild = node.children.last as? MarkdownNodeBase {
      if let blockNode = lastChild as? any MarkdownBlockNode {
        // Check if any builder can continue this block
        for builder in blockBuilders {
          if builder.canContinue(block: blockNode, line: line) {
            return blockNode
          }
        }
      }
      
      // Recursively check nested structures
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
  
  /// Process a line that continues an existing block
  private func processContinuationLine(_ line: MarkdownLine, for block: any MarkdownBlockNode, state: inout MarkdownConstructState) {
    // Find the builder for this block and let it process the line
    for builder in blockBuilders {
      if builder.canContinue(block: block, line: line) {
        _ = builder.processLine(block: block, line: line, state: &state)
        return
      }
    }
  }
  
  /// Process a line that opens a new block
  private func processOpeningLine(_ line: MarkdownLine, for block: any MarkdownBlockNode, state: inout MarkdownConstructState) {
    // Find the builder for this block and let it process the opening line
    for builder in blockBuilders {
      if canBuilderHandle(builder, blockType: block.blockType) {
        _ = builder.processLine(block: block, line: line, state: &state)
        return
      }
    }
  }
  
  /// Create and process a paragraph for this line
  private func createAndProcessParagraph(for line: MarkdownLine, context: inout CodeConstructContext<Node, Token>, state: inout MarkdownConstructState) {
    // Create a new paragraph
    let paragraph = createParagraphBlock()
    context.current.append(paragraph as! MarkdownNodeBase)
    
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
    case "heading": return builder is MarkdownATXHeadingBuilder
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
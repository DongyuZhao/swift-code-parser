import CodeParserCore
import Foundation

/// MarkdownBlockBuilder - The main CodeNodeBuilder implementation for Markdown
/// 
/// This class processes Markdown tokens line by line using the AST (context.current) as the editable single source of truth.
/// For each line, it determines what block the line belongs to and directly edits the AST to reflect this.
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
  
  /// Main CodeNodeBuilder implementation - processes tokens line by line, editing AST directly
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    
    // Extract lines from remaining tokens
    let remainingTokens = Array(context.tokens[context.consuming...])
    guard !remainingTokens.isEmpty else { return false }

    let lines = extractLines(from: remainingTokens)
    guard !lines.isEmpty else { return false }
    
    // Process each line, directly editing the AST to reflect the line content
    for line in lines {
      processLine(line, context: &context)
    }
    
    // Finalize any incomplete blocks
    finalizeIncompleteBlocks(context: &context)
    
    // Consume all processed tokens
    context.consuming = context.tokens.count
    
    return true
  }
  
  /// Process a single line by determining what block it belongs to and editing the AST
  private func processLine(_ line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) {
    // 1. Check if this line continues an existing block in the AST
    if let continueingBlock = findContinuingBlock(for: line, in: context.current) {
      // Add this line to the existing block
      addLineToBlock(line, block: continueingBlock)
      return
    }
    
    // 2. Check if this line can interrupt an existing block
    if let blockToInterrupt = findInterruptibleBlock(for: line, in: context.current) {
      // Finalize the interrupted block and start a new one
      finalizeBlock(blockToInterrupt)
    }
    
    // 3. Try to start a new block with this line
    if let newBlock = createNewBlock(for: line) {
      // Add the new block to the AST
      addBlockToAST(newBlock, context: &context)
      // Add this line to the new block
      addLineToBlock(line, block: newBlock)
    } else {
      // 4. Fallback: treat as paragraph if nothing else matches
      let paragraph = createParagraphBlock()
      addBlockToAST(paragraph, context: &context)
      addLineToBlock(line, block: paragraph)
    }
  }
  
  /// Find a block in the AST that this line can continue
  private func findContinuingBlock(for line: MarkdownLine, in node: CodeNode<MarkdownNodeElement>) -> (any MarkdownBlockNode)? {
    // Look for the last block that can continue with this line
    // Walk the AST to find blocks that can accept this line
    if let lastChild = node.children.last as? MarkdownNodeBase {
      if let blockNode = lastChild as? any MarkdownBlockNode {
        // Check if any builder can continue this block with this line
        for builder in blockBuilders {
          if builder.canContinue(block: blockNode, line: line) {
            return blockNode
          }
        }
      }
      
      // Recursively check children
      if let continueingBlock = findContinuingBlock(for: line, in: lastChild) {
        return continueingBlock
      }
    }
    
    return nil
  }
  
  /// Find a block that can be interrupted by this line
  private func findInterruptibleBlock(for line: MarkdownLine, in node: CodeNode<MarkdownNodeElement>) -> (any MarkdownBlockNode)? {
    // Check if any new block type can interrupt existing blocks
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        // Check if this builder type can interrupt existing blocks
        if canInterrupt(builderType: type(of: builder)) {
          // Find the block to interrupt (usually the last paragraph)
          if let lastChild = node.children.last as? MarkdownNodeBase,
             let blockNode = lastChild as? any MarkdownBlockNode,
             canBeInterrupted(blockNode) {
            return blockNode
          }
        }
      }
    }
    return nil
  }
  
  /// Check if a builder type can interrupt other blocks
  private func canInterrupt(builderType: MarkdownBlockBuilderProtocol.Type) -> Bool {
    return builderType is MarkdownATXHeadingBuilder.Type ||
           builderType is MarkdownThematicBreakBuilder.Type ||
           builderType is MarkdownFencedCodeBlockBuilder.Type ||
           builderType is MarkdownBlockquoteBuilder.Type ||
           builderType is MarkdownListItemBuilder.Type
  }
  
  /// Check if a block can be interrupted
  private func canBeInterrupted(_ block: any MarkdownBlockNode) -> Bool {
    // Only paragraphs can typically be interrupted
    return block.blockType == "paragraph"
  }
  
  /// Try to create a new block for this line
  private func createNewBlock(for line: MarkdownLine) -> (any MarkdownBlockNode)? {
    // Try each builder to see if it can create a block for this line
    for builder in blockBuilders {
      if builder.canStart(line: line) {
        return builder.createBlock(from: line)
      }
    }
    return nil
  }
  
  /// Create a default paragraph block
  private func createParagraphBlock() -> any MarkdownBlockNode {
    // Use a dummy range - the range will be updated when content is added
    let dummyString = ""
    let range = dummyString.startIndex..<dummyString.endIndex
    return ParagraphNode(range: range)
  }
  
  /// Add a block to the AST at the appropriate location
  private func addBlockToAST(_ block: any MarkdownBlockNode, context: inout CodeConstructContext<Node, Token>) {
    // Simply add to the current node - AST structure determines the hierarchy
    context.current.append(block as! MarkdownNodeBase)
  }
  
  /// Add a line to an existing block by delegating to the appropriate builder
  private func addLineToBlock(_ line: MarkdownLine, block: any MarkdownBlockNode) {
    // Find the builder that handles this block type and delegate
    for builder in blockBuilders {
      if builder.canContinue(block: block, line: line) {
        _ = builder.processLine(block: block, line: line)
        return
      }
    }
  }
  
  /// Finalize a block by delegating to the appropriate builder
  private func finalizeBlock(_ block: any MarkdownBlockNode) {
    // Find the builder that handles this block type and finalize
    for builder in blockBuilders {
      if canBuilderHandle(builder, blockType: block.blockType) {
        builder.closeBlock(block: block)
        return
      }
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
  
  /// Finalize any incomplete blocks in the AST
  private func finalizeIncompleteBlocks(context: inout CodeConstructContext<Node, Token>) {
    // Walk the AST and finalize any blocks that need it
    finalizeBlocksRecursively(node: context.current)
  }
  
  /// Recursively finalize blocks in the AST
  private func finalizeBlocksRecursively(node: CodeNode<MarkdownNodeElement>) {
    for child in node.children {
      if let markdownChild = child as? MarkdownNodeBase {
        if let blockNode = markdownChild as? any MarkdownBlockNode {
          finalizeBlock(blockNode)
        }
        // Recursively finalize children
        finalizeBlocksRecursively(node: markdownChild)
      }
    }
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
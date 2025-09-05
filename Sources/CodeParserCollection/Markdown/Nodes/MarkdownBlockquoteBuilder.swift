import CodeParserCore
import Foundation

/// Builder for blockquotes (> quoted text)
/// Implements CommonMark specification for blockquotes (Spec 024)
public class MarkdownBlockquoteBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Blockquotes can be indented 0-3 spaces
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces > 3 {
      return false
    }
    
    // Look for '>' marker after whitespace
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    return found
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard block.blockType == "blockquote" else { return false }
    
    // Blockquotes can continue with lines that start with '>'
    // or with lazy continuation (lines without '>')
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces > 3 {
      return false
    }
    
    // Can continue with '>' lines
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    if found {
      return true
    }
    
    // Can continue with lazy continuation (non-blank lines)
    if !line.isBlank {
      return true
    }
    
    // Blank lines generally end blockquotes
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    let blockquote = MarkdownBlockquote(level: 1)
    
    // Set package-level indentation properties
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    let (found, markerColumn, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    
    if found {
      blockquote.indent = leadingSpaces
      blockquote.markerColumn = markerColumn
      blockquote.contentColumn = MarkdownIndentation.findContentColumn(tokens: line.tokens, afterMarkerAt: markerColumn)
    }
    
    return blockquote
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    guard let blockquote = block as? MarkdownBlockquote else { return false }
    
    // Find content tokens after the '>' marker using package-level properties
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: state.tokens, marker: ">", afterWhitespace: true)
    if found {
      // Remove content up to the content column (after '> ')
      contentTokens = MarkdownIndentation.removeIndentation(from: state.tokens, upToColumn: blockquote.contentColumn)
    } else {
      // Lazy continuation - use tokens after the blockquote's indent
      contentTokens = MarkdownIndentation.removeIndentation(from: state.tokens, upToColumn: blockquote.indent)
    }
    
    // Update state with remaining content tokens for MarkdownBlockBuilder to process
    state.tokens = contentTokens
    
    // Only signal for more processing if there are actually tokens to process
    if !contentTokens.isEmpty {
      state.currentLineProcessed = false // Signal that remaining tokens need processing
    } else {
      state.currentLineProcessed = true // No more tokens to process
    }
    
    return true
  }
  
  /// Close the block - no special processing needed as content is parsed recursively by MarkdownBlockBuilder
  public func closeBlock(block: any MarkdownBlockNode) {
    // No special closing logic needed - the recursive parsing is handled by MarkdownBlockBuilder
  }
}
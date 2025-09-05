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
    
    // Process the initial line
    _ = processLine(block: blockquote, line: line)
    
    return blockquote
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let blockquote = block as? MarkdownBlockquote else { return false }
    
    // Find content tokens after the '>' marker using package-level properties
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    if found {
      // Remove content up to the content column (after '> ')
      contentTokens = MarkdownIndentation.removeIndentation(from: line.tokens, upToColumn: blockquote.contentColumn)
    } else {
      // Lazy continuation - use tokens after the blockquote's indent
      contentTokens = MarkdownIndentation.removeIndentation(from: line.tokens, upToColumn: blockquote.indent)
    }
    
    // Add content tokens to a temporary buffer for recursive parsing
    // We'll accumulate all blockquote content and then parse it recursively
    if !blockquote.children.isEmpty && blockquote.children.last?.element == .content {
      // Continue accumulating content
      if let contentNode = blockquote.children.last as? ContentNode {
        // Add a newline between lines for proper parsing
        if !contentNode.tokens.isEmpty {
          let syntheticNewline = MarkdownToken(element: .newline, text: "\n", range: "".startIndex..<"".endIndex)
          contentNode.tokens.append(syntheticNewline)
        }
        contentNode.tokens.append(contentsOf: contentTokens)
      }
    } else {
      // Create new content accumulator
      let contentNode = ContentNode(tokens: contentTokens)
      blockquote.children.append(contentNode)
    }
    
    return true
  }
  
  /// Close the block and parse accumulated content recursively
  public func closeBlock(block: any MarkdownBlockNode) {
    guard let blockquote = block as? MarkdownBlockquote else { return }
    
    // Find all accumulated content
    var allContentTokens: [any CodeToken<MarkdownTokenElement>] = []
    for child in blockquote.children {
      if let contentNode = child as? ContentNode {
        allContentTokens.append(contentsOf: contentNode.tokens)
      }
    }
    
    // Clear the temporary content nodes
    blockquote.children.removeAll()
    
    // Create a new parsing context for the blockquote content
    if !allContentTokens.isEmpty {
      let language = MarkdownLanguage()
      let subBuilder = MarkdownBlockBuilder()
      
      // Create parsing context for the content
      var state = MarkdownConstructState()
      var contentContext = CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>(
        root: blockquote,
        current: blockquote,
        tokens: allContentTokens,
        consuming: 0,
        state: state
      )
      
      // Parse the content recursively
      _ = subBuilder.build(from: &contentContext)
    }
  }
}
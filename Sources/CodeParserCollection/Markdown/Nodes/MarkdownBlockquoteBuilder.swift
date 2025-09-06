import CodeParserCore
import Foundation

/// Builder for blockquotes (> quoted text)
/// Implements CommonMark specification for blockquotes (Spec 024)
public class MarkdownBlockquoteBuilder: MarkdownBlockBuilderProtocol {
  
  public let priority: Int = 50 // Medium priority
  
  public init() {}
  
  public func canHandle(block: any MarkdownBlockNode) -> Bool {
    return block.blockType == "blockquote"
  }
  
  public func isContainerBuilder() -> Bool {
    return true
  }
  
  public func canInterrupt() -> Bool {
    return true
  }
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Blockquotes can be indented 0-3 spaces
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    print("DEBUG: MarkdownBlockquoteBuilder.canStart - line: '\(line.content)', leadingSpaces: \(leadingSpaces)")
    if leadingSpaces > 3 {
      print("DEBUG: MarkdownBlockquoteBuilder.canStart - too much indentation: \(leadingSpaces)")
      return false
    }
    
    // Look for '>' marker after whitespace
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    print("DEBUG: MarkdownBlockquoteBuilder.canStart - marker found: \(found)")
    return found
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard block.blockType == "blockquote" else { return false }
    
    print("DEBUG: MarkdownBlockquoteBuilder.canContinue - line: '\(line.content)'")
    
    // Blockquotes can continue with lines that start with '>'
    // or with lazy continuation (lines without '>')
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces > 3 {
      print("DEBUG: MarkdownBlockquoteBuilder.canContinue - too much indentation: \(leadingSpaces)")
      return false
    }
    
    // Can continue with '>' lines
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    if found {
      print("DEBUG: MarkdownBlockquoteBuilder.canContinue - found '>' marker")
      return true
    }
    
    // Can continue with lazy continuation (non-blank lines)
    if !line.isBlank {
      print("DEBUG: MarkdownBlockquoteBuilder.canContinue - lazy continuation (non-blank line)")
      return true
    }
    
    // Blank lines generally end blockquotes
    print("DEBUG: MarkdownBlockquoteBuilder.canContinue - blank line ends blockquote")
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
    
    print("DEBUG: MarkdownBlockquoteBuilder.processLine - line: '\(line.content)'")
    
    // Find content tokens after the '>' marker using package-level properties
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    let (found, _, _) = MarkdownIndentation.findMarkerPosition(tokens: state.tokens, marker: ">", afterWhitespace: true)
    if found {
      print("DEBUG: MarkdownBlockquoteBuilder.processLine - found '>' marker, removing indentation up to column \(blockquote.contentColumn)")
      // Remove content up to the content column (after '> ')
      contentTokens = MarkdownIndentation.removeIndentation(from: state.tokens, upToColumn: blockquote.contentColumn)
    } else {
      print("DEBUG: MarkdownBlockquoteBuilder.processLine - lazy continuation, removing indentation up to column \(blockquote.indent)")
      // Lazy continuation - use tokens after the blockquote's indent
      contentTokens = MarkdownIndentation.removeIndentation(from: state.tokens, upToColumn: blockquote.indent)
    }
    
    // Remove leading and trailing meaningless tokens, but preserve internal whitespace
    // that might be significant (like the space in "# Foo")
    var meaningfulTokens = contentTokens
    
    // Remove leading whitespace, newlines, and EOF
    while !meaningfulTokens.isEmpty && 
          (meaningfulTokens.first!.element == .whitespaces || 
           meaningfulTokens.first!.element == .newline || 
           meaningfulTokens.first!.element == .eof) {
      meaningfulTokens.removeFirst()
    }
    
    // Remove trailing whitespace, newlines, and EOF
    while !meaningfulTokens.isEmpty && 
          (meaningfulTokens.last!.element == .whitespaces || 
           meaningfulTokens.last!.element == .newline || 
           meaningfulTokens.last!.element == .eof) {
      meaningfulTokens.removeLast()
    }
    
    // Update state with remaining content tokens for MarkdownBlockBuilder to process
    state.tokens = meaningfulTokens
    print("DEBUG: MarkdownBlockquoteBuilder.processLine - remaining content tokens: \(contentTokens.count), meaningful tokens: \(meaningfulTokens.count)")
    print("DEBUG: MarkdownBlockquoteBuilder.processLine - meaningful token contents: [\(meaningfulTokens.map { "\"\($0.text)\"" }.joined(separator: ", "))]")
    
    // Handle blank lines within blockquotes specially
    // A blank line within a blockquote is when we have a ">" marker in the original line but no meaningful content
    let (foundInOriginal, _, _) = MarkdownIndentation.findMarkerPosition(tokens: line.tokens, marker: ">", afterWhitespace: true)
    
    if foundInOriginal && meaningfulTokens.isEmpty {
      // This is a blank line within the blockquote (e.g., ">\n" or ">")
      // We need to signal that a blank line occurred to close open paragraphs
      print("DEBUG: MarkdownBlockquoteBuilder.processLine - blank line within blockquote, signaling to close paragraphs")
      
      // Yield back a special blank line signal for the container to process
      state.tokens = [createBlankLineSignalToken()]
      state.currentLineProcessed = false
    } else if !meaningfulTokens.isEmpty {
      print("DEBUG: MarkdownBlockquoteBuilder.processLine - yielding back \(meaningfulTokens.count) meaningful tokens for processing")
      state.currentLineProcessed = false // Signal that remaining tokens need processing within this blockquote
    } else {
      print("DEBUG: MarkdownBlockquoteBuilder.processLine - no content tokens at all, line fully processed")
      state.currentLineProcessed = true // No more tokens to process
    }
    
    return true
  }
  
  /// Close the block - no special processing needed as content is parsed recursively by MarkdownBlockBuilder
  public func closeBlock(block: any MarkdownBlockNode) {
    // No special closing logic needed - the recursive parsing is handled by MarkdownBlockBuilder
  }
  
  /// When blockquote is closed, move context to its parent
  public func moveContextOnClose(block: any MarkdownBlockNode, context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) {
    // As mentioned by user: if blockquote builder decided to close a blockquote, 
    // just move the context.current pointer to its parent
    if let parent = context.current.parent {
      context.current = parent
    } else {
      // Fallback to root if no parent
      context.current = context.root
    }
  }
  
  /// Create a special token to signal a blank line within a blockquote
  private func createBlankLineSignalToken() -> any CodeToken<MarkdownTokenElement> {
    // Use a dummy range for the signal token
    let dummyString = ""
    let range = dummyString.startIndex..<dummyString.endIndex
    return MarkdownToken(element: .whitespaces, text: "__BLOCKQUOTE_BLANK_LINE__", range: range)
  }
}
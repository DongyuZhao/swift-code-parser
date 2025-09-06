import CodeParserCore
import Foundation

/// Builder for list items (- item, * item, + item, 1. item, etc.)
/// Implements CommonMark specification for list items (Spec 025)
public class MarkdownListItemBuilder: MarkdownBlockBuilderProtocol {
  
  public let priority: Int = 60 // Medium-low priority
  
  public init() {}
  
  public func canHandle(block: any MarkdownBlockNode) -> Bool {
    return block.blockType == "list_item"
  }
  
  public func isContainerBuilder() -> Bool {
    return true
  }
  
  public func canStart(line: MarkdownLine) -> Bool {
    // List items can be indented 0-3 spaces
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces > 3 {
      return false
    }
    
    // Work with tokens to find list markers
    var tokenIndex = 0
    
    // Skip leading whitespace
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { return false }
    
    let token = line.tokens[tokenIndex]
    
    // Check for unordered list markers (-, *, +)
    if token.element == .punctuation && (token.text == "-" || token.text == "*" || token.text == "+") {
      // Check what follows the marker
      let nextIndex = tokenIndex + 1
      if nextIndex >= line.tokens.count {
        return true // End of line after marker
      }
      
      let nextToken = line.tokens[nextIndex]
      // Must be followed by whitespace or end of line
      return nextToken.element == .whitespaces || nextToken.element == .newline || nextToken.element == .eof
    }
    
    // Check for ordered list markers (1., 2., etc.)
    if token.element == .characters {
      // Look for digit(s) followed by . or )
      let text = token.text
      if text.count <= 9 && text.allSatisfy(\.isNumber) {
        // Check next token for . or )
        let nextIndex = tokenIndex + 1
        if nextIndex < line.tokens.count {
          let nextToken = line.tokens[nextIndex]
          if nextToken.element == .punctuation && (nextToken.text == "." || nextToken.text == ")") {
            // Check what follows the delimiter
            let afterDelimiterIndex = nextIndex + 1
            if afterDelimiterIndex >= line.tokens.count {
              return true // End of line after delimiter
            }
            
            let afterDelimiterToken = line.tokens[afterDelimiterIndex]
            return afterDelimiterToken.element == .whitespaces || 
                   afterDelimiterToken.element == .newline || 
                   afterDelimiterToken.element == .eof
          }
        }
      }
    }
    
    return false
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let listItem = block as? MarkdownListItem, 
          block.blockType == "list_item" else { return false }
    
    // List items can continue with indented lines or blank lines
    // Use package-level properties for precise indentation checking
    
    if line.isBlank {
      return true // Blank lines can be part of list items
    }
    
    // Non-blank lines can continue if properly indented to the content column
    let meetsIndent = MarkdownIndentation.meetsIndentationRequirement(
      tokens: line.tokens, 
      requiredColumn: listItem.contentColumn
    )
    
    // Also check that it doesn't start a new list item
    return meetsIndent && !canStart(line: line)
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    // Extract marker information using token-based approach
    var tokenIndex = 0
    
    // Skip leading whitespace and calculate positions
    let (leadingSpaces, afterWhitespaceColumn, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { return nil }
    
    var marker = ""
    let markerColumn = afterWhitespaceColumn
    var markerLength = 0
    var contentColumn = afterWhitespaceColumn
    
    let token = line.tokens[tokenIndex]
    
    if token.element == .punctuation && (token.text == "-" || token.text == "*" || token.text == "+") {
      marker = token.text
      markerLength = 1
      tokenIndex += 1
      
      // Check for optional whitespace after marker
      if tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
        let whitespaceToken = line.tokens[tokenIndex]
        contentColumn = markerColumn + markerLength + whitespaceToken.text.count
      } else {
        contentColumn = markerColumn + markerLength
      }
    } else if token.element == .characters && token.text.allSatisfy(\.isNumber) {
      marker = token.text
      markerLength = token.text.count
      tokenIndex += 1
      
      // Get the delimiter (. or ))
      if tokenIndex < line.tokens.count {
        let delimiterToken = line.tokens[tokenIndex]
        marker += delimiterToken.text
        markerLength += delimiterToken.text.count
        tokenIndex += 1
        
        // Check for optional whitespace after delimiter
        if tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
          let whitespaceToken = line.tokens[tokenIndex]
          contentColumn = markerColumn + markerLength + whitespaceToken.text.count
        } else {
          contentColumn = markerColumn + markerLength
        }
      }
    }
    
    // Return just the list item - the main builder will handle container creation
    let listItem = MarkdownListItem(marker: marker)
    
    // Set package-level indentation properties
    listItem.markerIndent = leadingSpaces
    listItem.markerColumn = markerColumn
    listItem.contentColumn = contentColumn
    listItem.markerLength = markerLength
    
    // Set the old properties for backward compatibility
    listItem.contentIndent = contentColumn
    
    return listItem
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    guard let listItem = block as? MarkdownListItem else { return false }
    
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    if listItem.children.isEmpty {
      // First line - extract content after marker using package-level properties
      contentTokens = MarkdownIndentation.removeIndentation(from: line.tokens, upToColumn: listItem.contentColumn)
    } else {
      // Continuation line - remove indentation up to content column
      contentTokens = MarkdownIndentation.removeIndentation(from: line.tokens, upToColumn: listItem.contentColumn)
    }
    
    // Check if there's actual content to process
    let hasContent = contentTokens.contains { token in
      token.element != .whitespaces && token.element != .newline && token.element != .eof
    }
    
    if hasContent {
      // Yield back the content tokens for processing within the list item
      state.tokens = contentTokens
      state.currentLineProcessed = false // Let the container processing handle the content
    } else {
      // No content to process, mark as done
      state.currentLineProcessed = true
    }
    
    return true
  }
  
  /// List items cannot transform blocks
  public func canTransform(block: any MarkdownBlockNode, with line: MarkdownLine) -> Bool {
    return false
  }
  
  /// List items cannot transform blocks
  public func transform(block: any MarkdownBlockNode, with line: MarkdownLine) -> Bool {
    return false
  }
  
  /// List items generally do not interrupt other blocks except in special circumstances
  public func canInterrupt() -> Bool {
    return false
  }
  
  /// Move context when list item is closed - move to parent to allow new list items
  public func moveContextOnClose(block: any MarkdownBlockNode, context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) {
    // List items should move context to their parent (the list container)
    if let parent = context.current.parent {
      context.current = parent
    }
  }
}
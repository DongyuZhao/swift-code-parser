import CodeParserCore
import Foundation

/// Markdown code span builder for inline code
/// Handles code spans (`code`) according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#code-spans
public class MarkdownCodeSpanBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 10 }
  public var inlineType: MarkdownNodeElement { return .code }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count else { return false }
    let token = tokens[position]
    
    // Check for backtick character
    return token.element == .punctuation && token.text == "`"
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    guard position < tokens.count else { return nil }
    let token = tokens[position]
    
    // Must be a backtick
    guard token.element == .punctuation && token.text == "`" else {
      return nil
    }
    
    // Count opening backticks
    var openingBackticks = 0
    var currentPos = position
    
    while currentPos < tokens.count && 
          tokens[currentPos].element == .punctuation && 
          tokens[currentPos].text == "`" {
      openingBackticks += 1
      currentPos += 1
    }
    
    // Look for matching closing backticks
    var searchPos = currentPos
    var codeContent = ""
    
    while searchPos < tokens.count {
      // Check if we found closing backticks
      if tokens[searchPos].element == .punctuation && tokens[searchPos].text == "`" {
        // Count closing backticks
        var closingBackticks = 0
        var closingPos = searchPos
        
        while closingPos < tokens.count && 
              tokens[closingPos].element == .punctuation && 
              tokens[closingPos].text == "`" {
          closingBackticks += 1
          closingPos += 1
        }
        
        // If we found matching number of backticks, we have a code span
        if closingBackticks == openingBackticks {
          // Extract the code content
          codeContent = extractCodeContent(
            tokens: tokens,
            startPos: currentPos,
            endPos: searchPos
          )
          
          // Update position to after the closing backticks
          position = closingPos
          
          // Create and return the code span node
          return CodeSpanNode(code: codeContent)
        } else {
          // Not a match, continue searching
          searchPos = closingPos
        }
      } else {
        searchPos += 1
      }
    }
    
    // No matching closing backticks found - treat as literal backticks
    position += 1
    return TextNode(content: "`")
  }
  
  /// Extract code content between opening and closing backticks
  /// Applies CommonMark rules for code span content processing
  private func extractCodeContent(
    tokens: [any CodeToken<MarkdownTokenElement>],
    startPos: Int,
    endPos: Int
  ) -> String {
    var content = ""
    
    for i in startPos..<endPos {
      let token = tokens[i]
      
      // Convert newlines to single spaces in code spans
      if token.element == .newline {
        content += " "
      } else {
        content += token.text
      }
    }
    
    // Apply CommonMark code span rules:
    // 1. Remove one leading and one trailing space if both are present
    // 2. Remove leading and trailing whitespace only if the content consists entirely of whitespace
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.isEmpty {
      // Content is entirely whitespace - return empty
      return ""
    } else if content.hasPrefix(" ") && content.hasSuffix(" ") && content.count > 2 {
      // Remove one leading and one trailing space
      let startIndex = content.index(content.startIndex, offsetBy: 1)
      let endIndex = content.index(content.endIndex, offsetBy: -1)
      return String(content[startIndex..<endIndex])
    } else {
      // Return content as-is
      return content
    }
  }
}
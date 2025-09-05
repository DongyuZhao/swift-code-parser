import CodeParserCore
import Foundation

/// Builder for processing inline code spans (`code`)
public class MarkdownCodeSpanBuilder {
  
  public init() {}
  
  /// Process code spans from tokens - backticks have higher precedence than emphasis
  public func processCodeSpans(in tokens: [any CodeToken<MarkdownTokenElement>]) -> [ProcessedCodeSpan] {
    var codeSpans: [ProcessedCodeSpan] = []
    var index = 0
    
    while index < tokens.count {
      let token = tokens[index]
      
      // Look for opening backticks - must be punctuation backtick
      guard token.element == .punctuation && token.text == "`" else {
        index += 1
        continue
      }
      
      // Count consecutive backticks for opening delimiter
      var openingBackticks = 0
      var openingStart = index
      while index < tokens.count && 
            tokens[index].element == .punctuation && 
            tokens[index].text == "`" {
        openingBackticks += 1
        index += 1
      }
      let openingEnd = index - 1
      
      // Look for matching closing backticks (same count)
      var closingStart: Int? = nil
      var searchIndex = index
      
      // Special case: if we're at the end after reading opening backticks, 
      // check if we can split them into opening and closing for empty code span
      if index >= tokens.count && openingBackticks % 2 == 0 && openingBackticks >= 2 {
        let delimiterLength = openingBackticks / 2
        // Split the backticks: first half is opening, second half is closing
        let realOpeningEnd = openingStart + delimiterLength - 1
        let closingStart = realOpeningEnd + 1
        let closingEnd = openingEnd
        
        let range = openingStart...closingEnd
        let codeSpan = ProcessedCodeSpan(range: range, backtickCount: delimiterLength)
        codeSpans.append(codeSpan)
        break
      }
      
      if index >= tokens.count {
        // No content, no closing - not a valid code span
        index = openingEnd + 1
        continue
      }
      
      while searchIndex < tokens.count {
        // Look for start of a backtick run
        if tokens[searchIndex].element == .punctuation && tokens[searchIndex].text == "`" {
          let runStart = searchIndex
          var runLength = 0
          
          // Count consecutive backticks in this run
          while searchIndex < tokens.count && 
                tokens[searchIndex].element == .punctuation && 
                tokens[searchIndex].text == "`" {
            runLength += 1
            searchIndex += 1
          }
          
          // If this run matches our opening length, we found the closing
          if runLength == openingBackticks {
            closingStart = runStart
            break
          }
        } else {
          searchIndex += 1
        }
      }
      
      if let closingStart = closingStart {
        // Found matching closing backticks
        let closingEnd = closingStart + openingBackticks - 1
        let range = openingStart...closingEnd
        let codeSpan = ProcessedCodeSpan(range: range, backtickCount: openingBackticks)
        codeSpans.append(codeSpan)
        
        // Continue from after the closing backticks
        index = closingEnd + 1
      } else {
        // No matching closing backticks found, continue from next character
        // Reset index to just after the opening backticks we couldn't match
        index = openingEnd + 1
      }
    }
    
    return codeSpans
  }
  
  /// Extract content from code span, handling whitespace normalization
  public func extractCodeContent(from tokens: [any CodeToken<MarkdownTokenElement>], in range: ClosedRange<Int>, backtickCount: Int) -> String {
    // Skip backtick tokens at the beginning and end
    let contentStart = range.lowerBound + backtickCount
    let contentEnd = range.upperBound - backtickCount
    
    guard contentStart <= contentEnd else {
      return ""
    }
    
    let contentTokens = Array(tokens[contentStart...contentEnd])
    var content = contentTokens.map { $0.text }.joined()
    
    // Normalize whitespace according to CommonMark spec:
    // - Single spaces at beginning and end are stripped if there are non-space characters
    // - Line endings are converted to spaces
    
    // Convert line endings to spaces first
    content = content.replacingOccurrences(of: "\n", with: " ")
    content = content.replacingOccurrences(of: "\r\n", with: " ")
    content = content.replacingOccurrences(of: "\r", with: " ")
    content = content.replacingOccurrences(of: "__SOFT_LINE_BREAK__", with: " ")
    content = content.replacingOccurrences(of: "__HARD_LINE_BREAK__", with: " ")
    
    // Strip single leading and trailing spaces if there are non-space characters
    if content.count > 2 && content.hasPrefix(" ") && content.hasSuffix(" ") && 
       content.dropFirst().dropLast().contains(where: { $0 != " " }) {
      content = String(content.dropFirst().dropLast())
    }
    
    return content
  }
}

/// Processed code span range information
public struct ProcessedCodeSpan {
  let range: ClosedRange<Int>
  let backtickCount: Int
}
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
      
      // Look for opening backticks
      guard token.element == .punctuation && token.text.hasPrefix("`") else {
        index += 1
        continue
      }
      
      let openingBackticks = token.text.count
      let openingIndex = index
      
      // Look for matching closing backticks
      var closingIndex: Int? = nil
      var searchIndex = index + 1
      
      while searchIndex < tokens.count {
        let searchToken = tokens[searchIndex]
        
        if searchToken.element == .punctuation && 
           searchToken.text.hasPrefix("`") && 
           searchToken.text.count == openingBackticks {
          closingIndex = searchIndex
          break
        }
        
        searchIndex += 1
      }
      
      if let closingIndex = closingIndex {
        // Found matching closing backticks
        let range = openingIndex...closingIndex
        let codeSpan = ProcessedCodeSpan(range: range, backtickCount: openingBackticks)
        codeSpans.append(codeSpan)
        
        // Skip past the closing backticks
        index = closingIndex + 1
      } else {
        // No matching closing backticks found
        index += 1
      }
    }
    
    return codeSpans
  }
  
  /// Extract content from code span, handling whitespace normalization
  public func extractCodeContent(from tokens: [any CodeToken<MarkdownTokenElement>], in range: ClosedRange<Int>) -> String {
    let contentStart = range.lowerBound + 1
    let contentEnd = range.upperBound - 1
    
    guard contentStart <= contentEnd else {
      return ""
    }
    
    let contentTokens = Array(tokens[contentStart...contentEnd])
    var content = contentTokens.map { $0.text }.joined()
    
    // Normalize whitespace according to CommonMark spec:
    // - Single spaces at beginning and end are stripped if there are non-space characters
    // - All other whitespace is collapsed to single spaces
    if content.count > 2 && content.hasPrefix(" ") && content.hasSuffix(" ") && 
       content.dropFirst().dropLast().contains(where: { $0 != " " }) {
      content = String(content.dropFirst().dropLast())
    }
    
    // Collapse multiple spaces to single spaces (but preserve single spaces)
    content = content.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    
    return content
  }
}

/// Processed code span range information
public struct ProcessedCodeSpan {
  let range: ClosedRange<Int>
  let backtickCount: Int
}
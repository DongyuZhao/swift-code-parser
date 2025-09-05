import CodeParserCore
import Foundation

/// Builder for processing strikethrough text (~~text~~)
public class MarkdownStrikethroughBuilder {
  
  public init() {}
  
  /// Process strikethrough from tokens using delimiter matching
  public func processStrikethrough(in tokens: [any CodeToken<MarkdownTokenElement>]) -> [ProcessedStrikethrough] {
    var strikethroughs: [ProcessedStrikethrough] = []
    var delimiters: [StrikethroughDelimiter] = []
    
    // Build delimiter list
    var index = 0
    while index < tokens.count {
      let token = tokens[index]
      
      // Look for ~~ delimiters
      guard token.element == .punctuation && token.text == "~~" else {
        index += 1
        continue
      }
      
      // Check flanking rules
      let (canOpen, canClose) = determineFlankingRules(at: index, in: tokens)
      
      if canOpen || canClose {
        let delimiter = StrikethroughDelimiter(
          tokenIndex: index,
          canOpen: canOpen,
          canClose: canClose
        )
        delimiters.append(delimiter)
      }
      
      index += 1
    }
    
    // Process delimiters to find matches
    var delimiterIndex = 0
    while delimiterIndex < delimiters.count {
      let currentDelimiter = delimiters[delimiterIndex]
      
      // Only process closing delimiters
      guard currentDelimiter.canClose else {
        delimiterIndex += 1
        continue
      }
      
      // Look backwards for opening delimiter
      var openingIndex: Int? = nil
      for i in (0..<delimiterIndex).reversed() {
        let openingDelimiter = delimiters[i]
        
        if openingDelimiter.canOpen {
          openingIndex = i
          break
        }
      }
      
      if let openingIndex = openingIndex {
        let openingDelimiter = delimiters[openingIndex]
        
        // Create strikethrough range
        let range = openingDelimiter.tokenIndex...currentDelimiter.tokenIndex
        strikethroughs.append(ProcessedStrikethrough(range: range))
        
        // Remove processed delimiters
        delimiters.removeSubrange(openingIndex...delimiterIndex)
        delimiterIndex = openingIndex
      } else {
        delimiterIndex += 1
      }
    }
    
    return strikethroughs
  }
  
  /// Determine flanking rules for strikethrough delimiters
  private func determineFlankingRules(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> (canOpen: Bool, canClose: Bool) {
    // Get preceding and following characters
    let precedingChar = getPrecedingCharacter(at: index, in: tokens)
    let followingChar = getFollowingCharacter(at: index, in: tokens)
    
    // Strikethrough uses same flanking rules as * emphasis
    let leftFlanking = !followingChar.isWhitespace && 
                      (!followingChar.isPunctuation || precedingChar.isWhitespace || precedingChar.isPunctuation)
                      
    let rightFlanking = !precedingChar.isWhitespace && 
                       (!precedingChar.isPunctuation || followingChar.isWhitespace || followingChar.isPunctuation)
    
    return (canOpen: leftFlanking, canClose: rightFlanking)
  }
  
  /// Get character preceding the token at index
  private func getPrecedingCharacter(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Character {
    if index == 0 { return "\n" }
    
    let prevToken = tokens[index - 1]
    if let lastChar = prevToken.text.last {
      return lastChar
    }
    return "\n"
  }
  
  /// Get character following the token at index  
  private func getFollowingCharacter(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Character {
    if index >= tokens.count - 1 { return "\n" }
    
    let nextToken = tokens[index + 1]
    if let firstChar = nextToken.text.first {
      return firstChar
    }
    return "\n"
  }
}

/// Delimiter for strikethrough processing
private struct StrikethroughDelimiter {
  let tokenIndex: Int
  let canOpen: Bool
  let canClose: Bool
}

/// Processed strikethrough range
public struct ProcessedStrikethrough {
  let range: ClosedRange<Int>
}
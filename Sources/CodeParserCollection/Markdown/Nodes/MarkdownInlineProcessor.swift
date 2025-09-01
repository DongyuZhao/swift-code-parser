import CodeParserCore
import Foundation

/// Extension to help with character classification
extension Character {
  var isPunctuation: Bool {
    return unicodeScalars.allSatisfy { scalar in
      CharacterSet.punctuationCharacters.contains(scalar)
    }
  }
}

/// Delimiter for CommonMark emphasis processing
private struct EmphasisDelimiter {
  let tokenIndex: Int
  let character: Character
  let originalLength: Int
  let remainingLength: Int
  let canOpen: Bool
  let canClose: Bool
  
  init(tokenIndex: Int, character: Character, originalLength: Int, remainingLength: Int, canOpen: Bool, canClose: Bool) {
    self.tokenIndex = tokenIndex
    self.character = character
    self.originalLength = originalLength
    self.remainingLength = remainingLength
    self.canOpen = canOpen
    self.canClose = canClose
  }
  
  func withRemainingLength(_ length: Int) -> EmphasisDelimiter {
    return EmphasisDelimiter(tokenIndex: tokenIndex, character: character, originalLength: originalLength, remainingLength: length, canOpen: canOpen, canClose: canClose)
  }
}

/// CommonMark-compliant inline processor using delimiter stack algorithm
/// Works directly with tokens without string conversion
public class MarkdownInlineProcessor {
  
  public init() {}
  
  /// Process inline content from tokens using CommonMark delimiter stack algorithm
  public func processInlineTokens(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
    if tokens.isEmpty {
      return []
    }
    
    // Build delimiter stack from punctuation tokens only
    let delimiterStack = buildDelimiterStack(from: tokens)
    
    // Process emphasis using delimiter stack
    let processedRanges = processEmphasisWithDelimiterStack(tokens: tokens, delimiters: delimiterStack)
    
    // Build final node tree
    return buildNodeTree(from: tokens, processedRanges: processedRanges)
  }
  
  /// Build delimiter stack from punctuation tokens
  private func buildDelimiterStack(from tokens: [any CodeToken<MarkdownTokenElement>]) -> [EmphasisDelimiter] {
    var delimiters: [EmphasisDelimiter] = []
    
    for (index, token) in tokens.enumerated() {
      // Only consider punctuation tokens - escaped content is in .characters tokens
      guard token.element == .punctuation else { continue }
      guard token.text == "*" || token.text == "_" else { continue }
      
      let character = Character(token.text)
      
      // Determine if this delimiter can open or close emphasis
      let (canOpen, canClose) = determineFlankingRules(at: index, in: tokens)
      
      if canOpen || canClose {
        let delimiter = EmphasisDelimiter(
          tokenIndex: index,
          character: character,
          originalLength: 1, // Each punctuation token is length 1
          remainingLength: 1,
          canOpen: canOpen,
          canClose: canClose
        )
        delimiters.append(delimiter)
      }
    }
    
    return delimiters
  }
  
  /// Determine flanking rules for emphasis delimiters
  private func determineFlankingRules(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> (canOpen: Bool, canClose: Bool) {
    let char = tokens[index].text.first!
    
    // Get preceding and following characters
    let precedingChar = getPrecedingCharacter(at: index, in: tokens)
    let followingChar = getFollowingCharacter(at: index, in: tokens)
    
    // Determine if left-flanking and right-flanking
    let leftFlanking = !followingChar.isWhitespace && 
                      (!followingChar.isPunctuation || precedingChar.isWhitespace || precedingChar.isPunctuation)
                      
    let rightFlanking = !precedingChar.isWhitespace && 
                       (!precedingChar.isPunctuation || followingChar.isWhitespace || followingChar.isPunctuation)
    
    // Rules for * and _
    if char == "*" {
      return (canOpen: leftFlanking, canClose: rightFlanking)
    } else { // char == "_"
      let canOpen = leftFlanking && (!rightFlanking || precedingChar.isPunctuation)
      let canClose = rightFlanking && (!leftFlanking || followingChar.isPunctuation)
      return (canOpen: canOpen, canClose: canClose)
    }
  }
  
  /// Get character preceding the token at index
  private func getPrecedingCharacter(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Character {
    if index == 0 { return "\n" } // Beginning of line
    
    let prevToken = tokens[index - 1]
    if let lastChar = prevToken.text.last {
      return lastChar
    }
    return "\n"
  }
  
  /// Get character following the token at index  
  private func getFollowingCharacter(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Character {
    if index >= tokens.count - 1 { return "\n" } // End of line
    
    let nextToken = tokens[index + 1]
    if let firstChar = nextToken.text.first {
      return firstChar
    }
    return "\n"
  }
  
  /// Process emphasis using CommonMark delimiter stack algorithm
  private func processEmphasisWithDelimiterStack(tokens: [any CodeToken<MarkdownTokenElement>], delimiters: [EmphasisDelimiter]) -> [ClosedRange<Int>] {
    var processedRanges: [ClosedRange<Int>] = []
    var delimiterStack = delimiters
    
    // Process delimiters from left to right
    var stackIndex = 0
    while stackIndex < delimiterStack.count {
      let currentDelimiter = delimiterStack[stackIndex]
      
      // Only process closing delimiters
      guard currentDelimiter.canClose else {
        stackIndex += 1
        continue
      }
      
      // Look backwards for matching opening delimiter
      var openingIndex: Int? = nil
      for i in (0..<stackIndex).reversed() {
        let openingDelimiter = delimiterStack[i]
        
        // Must be able to open and same character
        guard openingDelimiter.canOpen && openingDelimiter.character == currentDelimiter.character else {
          continue
        }
        
        openingIndex = i
        break
      }
      
      if let openingIndex = openingIndex {
        // Found matching pair - create emphasis
        let openingDelimiter = delimiterStack[openingIndex]
        let tokenRange = openingDelimiter.tokenIndex...currentDelimiter.tokenIndex
        processedRanges.append(tokenRange)
        
        // Remove processed delimiters from stack
        delimiterStack.removeSubrange(openingIndex...stackIndex)
        stackIndex = openingIndex
      } else {
        stackIndex += 1
      }
    }
    
    return processedRanges
  }
  
  /// Build node tree from tokens and processed emphasis ranges
  private func buildNodeTree(from tokens: [any CodeToken<MarkdownTokenElement>], processedRanges: [ClosedRange<Int>]) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var index = 0
    
    while index < tokens.count {
      // Check if this token is part of an emphasis range
      let emphasisRange = processedRanges.first { $0.contains(index) }
      
      if let range = emphasisRange {
        // Create emphasis node
        let openingToken = tokens[range.lowerBound]
        let closingToken = tokens[range.upperBound]
        
        // Skip opening delimiter
        let contentStart = range.lowerBound + 1
        let contentEnd = range.upperBound - 1
        
        if contentStart <= contentEnd {
          let contentTokens = Array(tokens[contentStart...contentEnd])
          
          // Recursively process content
          let contentNodes = processInlineTokens(contentTokens)
          
          // Create appropriate emphasis node
          let emphasisNode = EmphasisNode(content: "")
          for child in contentNodes {
            emphasisNode.append(child)
          }
          
          nodes.append(emphasisNode)
        }
        
        // Skip to after this range
        index = range.upperBound + 1
      } else {
        // Regular token - convert to text
        let token = tokens[index]
        if token.element != .eof && token.element != .newline {
          if let lastNode = nodes.last as? MarkdownText {
            // Combine with previous text node
            lastNode.content += token.text
          } else {
            // Create new text node
            nodes.append(MarkdownText(content: token.text))
          }
        }
        index += 1
      }
    }
    
    return nodes
  }
}
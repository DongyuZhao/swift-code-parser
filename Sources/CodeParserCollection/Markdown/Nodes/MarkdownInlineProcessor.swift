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
  let length: Int
  let canOpen: Bool
  let canClose: Bool
  
  init(tokenIndex: Int, character: Character, length: Int, canOpen: Bool, canClose: Bool) {
    self.tokenIndex = tokenIndex
    self.character = character
    self.length = length
    self.canOpen = canOpen
    self.canClose = canClose
  }
}

/// Processed emphasis range with type information
private struct ProcessedEmphasis {
  let range: ClosedRange<Int>
  let isStrong: Bool // true for strong (**), false for regular (*)
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
    let processedEmphasis = processEmphasisWithDelimiterStack(tokens: tokens, delimiters: delimiterStack)
    
    // Build final node tree
    return buildNodeTree(from: tokens, processedEmphasis: processedEmphasis)
  }
  
  /// Build delimiter stack from punctuation tokens
  private func buildDelimiterStack(from tokens: [any CodeToken<MarkdownTokenElement>]) -> [EmphasisDelimiter] {
    var delimiters: [EmphasisDelimiter] = []
    var index = 0
    
    while index < tokens.count {
      let token = tokens[index]
      
      // Only consider punctuation tokens - escaped content is in .characters tokens
      guard token.element == .punctuation else {
        index += 1
        continue
      }
      
      guard token.text == "*" || token.text == "_" else {
        index += 1
        continue
      }
      
      let character = Character(token.text)
      
      // Count consecutive delimiters of the same type
      var delimiterLength = 0
      var currentIndex = index
      while currentIndex < tokens.count {
        let currentToken = tokens[currentIndex]
        if currentToken.element == .punctuation && currentToken.text == token.text {
          delimiterLength += 1
          currentIndex += 1
        } else {
          break
        }
      }
      
      // Determine if this delimiter run can open or close emphasis
      let (canOpen, canClose) = determineFlankingRules(at: index, delimiterLength: delimiterLength, in: tokens)
      
      if canOpen || canClose {
        let delimiter = EmphasisDelimiter(
          tokenIndex: index,
          character: character,
          length: delimiterLength,
          canOpen: canOpen,
          canClose: canClose
        )
        delimiters.append(delimiter)
      }
      
      // Skip past all the delimiters we just processed
      index = currentIndex
    }
    
    return delimiters
  }
  
  /// Determine flanking rules for emphasis delimiters
  private func determineFlankingRules(at index: Int, delimiterLength: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> (canOpen: Bool, canClose: Bool) {
    let char = tokens[index].text.first!
    
    // Get preceding and following characters
    let precedingChar = getPrecedingCharacter(at: index, in: tokens)
    let followingChar = getFollowingCharacter(at: index + delimiterLength - 1, in: tokens)
    
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
  private func processEmphasisWithDelimiterStack(tokens: [any CodeToken<MarkdownTokenElement>], delimiters: [EmphasisDelimiter]) -> [ProcessedEmphasis] {
    var processedEmphasis: [ProcessedEmphasis] = []
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
        let openingDelimiter = delimiterStack[openingIndex]
        
        // Determine how many delimiters to use (1 for emphasis, 2 for strong)
        let useCount = min(2, min(openingDelimiter.length, currentDelimiter.length))
        
        // Calculate actual token ranges
        let openingStartToken = openingDelimiter.tokenIndex
        let openingEndToken = openingDelimiter.tokenIndex + useCount - 1
        let closingStartToken = currentDelimiter.tokenIndex + currentDelimiter.length - useCount
        let closingEndToken = currentDelimiter.tokenIndex + currentDelimiter.length - 1
        
        // Create range for the entire emphasis span (including delimiters)
        let tokenRange = openingStartToken...closingEndToken
        let isStrong = (useCount == 2)
        
        processedEmphasis.append(ProcessedEmphasis(range: tokenRange, isStrong: isStrong))
        
        // Remove processed delimiters from stack
        delimiterStack.removeSubrange(openingIndex...stackIndex)
        stackIndex = openingIndex
      } else {
        stackIndex += 1
      }
    }
    
    return processedEmphasis
  }
  
  /// Build node tree from tokens and processed emphasis ranges
  private func buildNodeTree(from tokens: [any CodeToken<MarkdownTokenElement>], processedEmphasis: [ProcessedEmphasis]) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var index = 0
    
    while index < tokens.count {
      // Check if this token is part of an emphasis range
      let emphasisMatch = processedEmphasis.first { $0.range.contains(index) }
      
      if let emphasis = emphasisMatch {
        // Create emphasis node
        let range = emphasis.range
        
        // Calculate delimiter length (1 for *, 2 for **)
        let delimiterLength = emphasis.isStrong ? 2 : 1
        
        // Skip opening delimiters
        let contentStart = range.lowerBound + delimiterLength
        let contentEnd = range.upperBound - delimiterLength
        
        if contentStart <= contentEnd {
          let contentTokens = Array(tokens[contentStart...contentEnd])
          
          // Recursively process content
          let contentNodes = processInlineTokens(contentTokens)
          
          // Create appropriate emphasis node
          if emphasis.isStrong {
            let strongNode = StrongNode(content: "")
            for child in contentNodes {
              strongNode.append(child)
            }
            nodes.append(strongNode)
          } else {
            let emphasisNode = EmphasisNode(content: "")
            for child in contentNodes {
              emphasisNode.append(child)
            }
            nodes.append(emphasisNode)
          }
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
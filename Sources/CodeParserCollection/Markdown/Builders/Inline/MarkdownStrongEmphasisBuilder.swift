import CodeParserCore
import Foundation

/// Complete emphasis/strong processing builder for CommonMark compliance
/// Processes emphasis and strong emphasis in one pass to handle complex nesting
struct MarkdownStrongEmphasisBuilder: CodeNodeBuilder {
  typealias Node = MarkdownNodeElement
  typealias Token = MarkdownTokenElement

  /// Process emphasis and strong emphasis by finding complete pairs
  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    let startIndex = context.consuming
    
    guard startIndex < tokens.count else { return false }
    
    let startToken = tokens[startIndex]
    guard startToken.element == .punctuation && (startToken.text == "*" || startToken.text == "_") else {
      return false
    }
    
    // Find and process the first complete emphasis/strong pair starting at this position
    if let result = findCompleteEmphasisPair(startingAt: startIndex, tokens: tokens) {
      // Create the appropriate node
      let node: MarkdownNodeBase
      if result.isStrong {
        node = StrongNode(content: "")
      } else {
        node = EmphasisNode(content: "")
      }
      
      // Process content between delimiters
      let contentTokens = Array(tokens[result.contentStart..<result.contentEnd])
      processContent(contentTokens, into: node, context: &context)
      
      context.current.append(node)
      context.consuming = result.afterCloser
      return true
    }
    
    return false
  }
  
  /// Result of finding a complete emphasis pair
  private struct EmphasisResult {
    let contentStart: Int
    let contentEnd: Int
    let afterCloser: Int
    let isStrong: Bool
  }
  
  /// Find a complete emphasis/strong pair starting at the given position
  private func findCompleteEmphasisPair(
    startingAt startIndex: Int,
    tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> EmphasisResult? {
    
    guard startIndex < tokens.count,
          tokens[startIndex].element == .punctuation,
          let delimiterChar = tokens[startIndex].text.first,
          (delimiterChar == "*" || delimiterChar == "_") else {
      return nil
    }
    
    // Count opener delimiters
    var openerCount = 0
    var i = startIndex
    while i < tokens.count && 
          tokens[i].element == .punctuation && 
          tokens[i].text.first == delimiterChar {
      openerCount += 1
      i += 1
    }
    
    // Check if this can open
    let (canOpen, _) = determineDelimiterRuns(
      delimChar: delimiterChar,
      tokenIndex: startIndex,
      tokens: tokens
    )
    
    guard canOpen else { return nil }
    
    // Try to find matching closer, preferring strong (2 delims) over emphasis (1 delim)
    let tryOrder = openerCount >= 2 ? [2, 1] : [1]
    
    for useCount in tryOrder {
      guard useCount <= openerCount else { continue }
      
      let contentStart = startIndex + useCount
      
      // Look for matching closer
      var j = contentStart
      while j < tokens.count {
        let token = tokens[j]
        
        // Stop at newlines
        if token.element == .newline {
          break
        }
        
        // Found potential closer
        if token.element == .punctuation && token.text.first == delimiterChar {
          // Count closer delimiters
          var closerCount = 0
          var k = j
          while k < tokens.count && 
                tokens[k].element == .punctuation && 
                tokens[k].text.first == delimiterChar {
            closerCount += 1
            k += 1
          }
          
          // Check if this can close and has enough delimiters
          if closerCount >= useCount {
            let (_, canClose) = determineDelimiterRuns(
              delimChar: delimiterChar,
              tokenIndex: j,
              tokens: tokens
            )
            
            if canClose {
              return EmphasisResult(
                contentStart: contentStart,
                contentEnd: j,
                afterCloser: j + useCount,
                isStrong: useCount == 2
              )
            }
          }
          
          j = k
        } else {
          j += 1
        }
      }
    }
    
    return nil
  }
  
  /// Process content tokens, handling nested emphasis/strong
  private func processContent(
    _ contentTokens: [any CodeToken<MarkdownTokenElement>],
    into parentNode: MarkdownNodeBase,
    context: inout CodeConstructContext<Node, Token>
  ) {
    guard !contentTokens.isEmpty else { return }
    
    var buffer = ""
    var i = 0
    
    while i < contentTokens.count {
      let token = contentTokens[i]
      
      if token.element == .newline {
        if !buffer.isEmpty {
          parentNode.append(TextNode(content: buffer))
          buffer.removeAll()
        }
        parentNode.append(LineBreakNode(variant: .soft))
        i += 1
        continue
      }
      
      // Try to find nested emphasis/strong
      if token.element == .punctuation && (token.text == "*" || token.text == "_") {
        if let nestedResult = findCompleteEmphasisPair(startingAt: i, tokens: contentTokens) {
          // Found nested emphasis - flush buffer and create nested node
          if !buffer.isEmpty {
            parentNode.append(TextNode(content: buffer))
            buffer.removeAll()
          }
          
          let nestedNode: MarkdownNodeBase
          if nestedResult.isStrong {
            nestedNode = StrongNode(content: "")
          } else {
            nestedNode = EmphasisNode(content: "")
          }
          
          // Recursively process nested content
          let nestedContent = Array(contentTokens[nestedResult.contentStart..<nestedResult.contentEnd])
          processContent(nestedContent, into: nestedNode, context: &context)
          
          parentNode.append(nestedNode)
          i = nestedResult.afterCloser
          continue
        }
      }
      
      // Add to buffer
      buffer.append(token.text)
      i += 1
    }
    
    if !buffer.isEmpty {
      parentNode.append(TextNode(content: buffer))
    }
  }
  
  /// Determine if a delimiter run can open or close based on CommonMark rules
  private func determineDelimiterRuns(
    delimChar: Character,
    tokenIndex: Int,
    tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (canOpen: Bool, canClose: Bool) {
    
    let beforeChar = tokenIndex > 0 ? getLastChar(from: tokens[tokenIndex - 1]) : nil
    let afterChar = tokenIndex + 1 < tokens.count ? getFirstChar(from: tokens[tokenIndex + 1]) : nil
    
    let beforeIsWhitespace = beforeChar?.isWhitespace ?? true
    let afterIsWhitespace = afterChar?.isWhitespace ?? true
    let beforeIsPunctuation = beforeChar?.isPunctuation ?? false
    let afterIsPunctuation = afterChar?.isPunctuation ?? false
    
    let leftFlanking = !afterIsWhitespace && 
                      (!afterIsPunctuation || beforeIsWhitespace || beforeIsPunctuation)
    let rightFlanking = !beforeIsWhitespace && 
                        (!beforeIsPunctuation || afterIsWhitespace || afterIsPunctuation)
    
    if delimChar == "*" {
      return (canOpen: leftFlanking, canClose: rightFlanking)
    } else { // "_"
      let canOpen = leftFlanking && (!rightFlanking || beforeIsPunctuation)
      let canClose = rightFlanking && (!leftFlanking || afterIsPunctuation)
      return (canOpen: canOpen, canClose: canClose)
    }
  }
  
  /// Get the last character from a token
  private func getLastChar(from token: any CodeToken<MarkdownTokenElement>) -> Character? {
    return token.text.last
  }
  
  /// Get the first character from a token
  private func getFirstChar(from token: any CodeToken<MarkdownTokenElement>) -> Character? {
    return token.text.first
  }
}

// MARK: - Character Extensions
extension Character {
  var isPunctuation: Bool {
    return self.unicodeScalars.allSatisfy { scalar in
      CharacterSet.punctuationCharacters.contains(scalar)
    }
  }
}
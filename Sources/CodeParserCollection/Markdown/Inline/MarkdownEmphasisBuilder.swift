import CodeParserCore
import Foundation

/// Markdown emphasis builder implementing CommonMark delimiter stack algorithm
/// Handles single emphasis (*text* or _text_) according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis
public class MarkdownEmphasisBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 20 }
  public var inlineType: MarkdownNodeElement { return .emphasis }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count else { return false }
    let token = tokens[position]
    
    // Check for emphasis delimiters: * or _
    return token.element == .punctuation && (token.text == "*" || token.text == "_")
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
    
    // Must be a delimiter character
    guard token.element == .punctuation && (token.text == "*" || token.text == "_") else {
      return nil
    }
    
    // Count consecutive delimiter characters
    let delimiterChar = token.text
    var count = 0
    var currentPos = position
    
    while currentPos < tokens.count && 
          tokens[currentPos].element == .punctuation && 
          tokens[currentPos].text == delimiterChar {
      count += 1
      currentPos += 1
    }
    
    // For emphasis, we only care about single delimiters
    // (Strong emphasis will handle double delimiters)
    if count >= 1 {
      // Determine if this delimiter can open or close emphasis
      let (canOpen, canClose) = determineDelimiterCapabilities(
        tokens: tokens,
        position: position,
        count: count,
        delimiterChar: delimiterChar
      )
      
      // Try to close existing emphasis first (closer has precedence)
      if canClose {
        if let closerResult = tryCloseEmphasis(
          delimiterChar: delimiterChar,
          count: 1,
          position: position,
          delimiterStack: &delimiterStack
        ) {
          position = currentPos
          return closerResult
        }
      }
      
      // If we can open emphasis, add to delimiter stack
      if canOpen {
        let delimiterEntry = DelimiterEntry(
          character: delimiterChar,
          count: 1,
          position: position,
          canOpen: canOpen,
          canClose: canClose
        )
        delimiterStack.append(delimiterEntry)
        position += 1 // Only consume one delimiter for emphasis
        
        // Return the delimiter as text for now - it will be resolved later
        return TextNode(content: delimiterChar)
      }
    }
    
    // If we can't handle this as emphasis, let it be processed as text
    position += 1
    return TextNode(content: delimiterChar)
  }
  
  /// Determine if a delimiter can open and/or close emphasis
  /// Based on CommonMark rules for flanking delimiters
  private func determineDelimiterCapabilities(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    count: Int,
    delimiterChar: String
  ) -> (canOpen: Bool, canClose: Bool) {
    let isLeftFlanking = isLeftFlankingDelimiter(tokens: tokens, position: position, count: count)
    let isRightFlanking = isRightFlankingDelimiter(tokens: tokens, position: position, count: count)
    
    // Rules for * delimiters
    if delimiterChar == "*" {
      let canOpen = isLeftFlanking
      let canClose = isRightFlanking
      return (canOpen, canClose)
    }
    
    // Rules for _ delimiters (more restrictive)
    if delimiterChar == "_" {
      let canOpen = isLeftFlanking && (!isRightFlanking || isPrecededByPunctuation(tokens: tokens, position: position))
      let canClose = isRightFlanking && (!isLeftFlanking || isFollowedByPunctuation(tokens: tokens, position: position, count: count))
      return (canOpen, canClose)
    }
    
    return (false, false)
  }
  
  /// Check if delimiter is left-flanking (can potentially open emphasis)
  private func isLeftFlankingDelimiter(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    count: Int
  ) -> Bool {
    let nextPos = position + count
    
    // Must not be followed by whitespace
    if nextPos >= tokens.count {
      return false
    }
    
    let nextToken = tokens[nextPos]
    if nextToken.element == .whitespaces {
      return false
    }
    
    // Must not be followed by punctuation, OR must be preceded by whitespace or punctuation
    if isPunctuation(nextToken) {
      if position == 0 {
        return true
      }
      let prevToken = tokens[position - 1]
      return prevToken.element == .whitespaces || isPunctuation(prevToken)
    }
    
    return true
  }
  
  /// Check if delimiter is right-flanking (can potentially close emphasis)
  private func isRightFlankingDelimiter(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    count: Int
  ) -> Bool {
    // Must not be preceded by whitespace
    if position == 0 {
      return false
    }
    
    let prevToken = tokens[position - 1]
    if prevToken.element == .whitespaces {
      return false
    }
    
    // Must not be preceded by punctuation, OR must be followed by whitespace or punctuation
    if isPunctuation(prevToken) {
      let nextPos = position + count
      if nextPos >= tokens.count {
        return true
      }
      let nextToken = tokens[nextPos]
      return nextToken.element == .whitespaces || isPunctuation(nextToken)
    }
    
    return true
  }
  
  /// Check if a token is punctuation
  private func isPunctuation(_ token: any CodeToken<MarkdownTokenElement>) -> Bool {
    return token.element == .punctuation
  }
  
  /// Check if delimiter is preceded by punctuation
  private func isPrecededByPunctuation(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int
  ) -> Bool {
    guard position > 0 else { return false }
    return isPunctuation(tokens[position - 1])
  }
  
  /// Check if delimiter is followed by punctuation
  private func isFollowedByPunctuation(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    count: Int
  ) -> Bool {
    let nextPos = position + count
    guard nextPos < tokens.count else { return false }
    return isPunctuation(tokens[nextPos])
  }
  
  /// Try to close emphasis by finding a matching opener on the delimiter stack
  private func tryCloseEmphasis(
    delimiterChar: String,
    count: Int,
    position: Int,
    delimiterStack: inout [DelimiterEntry]
  ) -> MarkdownNodeBase? {
    // Look for a matching opener from the top of the stack
    for i in stride(from: delimiterStack.count - 1, through: 0, by: -1) {
      let opener = delimiterStack[i]
      
      // Must match character and be able to open
      if opener.character == delimiterChar && opener.canOpen && opener.count >= count {
        // Found a match - create emphasis node
        let emphasisNode = EmphasisNode(content: "")
        
        // Remove the opener from the stack
        delimiterStack.remove(at: i)
        
        // In a complete implementation, we would collect all the content between 
        // the opener and closer and add it to the emphasis node
        // For now, we'll create a simplified node
        
        return emphasisNode
      }
    }
    
    return nil
  }
}
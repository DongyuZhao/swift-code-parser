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
  
  private let codeSpanBuilder = MarkdownCodeSpanBuilder()
  private let strikethroughBuilder = MarkdownStrikethroughBuilder()
  
  public init() {}
  
  /// Process inline content from tokens using CommonMark delimiter stack algorithm
  /// Precedence: Code spans > Links > Emphasis/Strong > Strikethrough
  public func processInlineTokens(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
    if tokens.isEmpty {
      return []
    }
    
    // 1. Process code spans first (highest precedence)
    let codeSpans = codeSpanBuilder.processCodeSpans(in: tokens)
    
    // 2. Build delimiter stack for emphasis, excluding code span ranges
    let delimiterStack = buildDelimiterStack(from: tokens, excludingRanges: codeSpans.map { $0.range })
    let processedEmphasis = processEmphasisWithDelimiterStack(tokens: tokens, delimiters: delimiterStack)
    
    // 3. Process strikethrough (lower precedence than emphasis)
    let allUsedRanges = codeSpans.map { $0.range } + processedEmphasis.map { $0.range }
    let strikethroughTokens = filterTokensExcluding(tokens, ranges: allUsedRanges)
    let processedStrikethrough = strikethroughBuilder.processStrikethrough(in: strikethroughTokens)
    
    // 4. Build final node tree
    return buildNodeTree(from: tokens, 
                        codeSpans: codeSpans,
                        processedEmphasis: processedEmphasis,
                        processedStrikethrough: processedStrikethrough)
  }
  
  /// Filter tokens excluding those in specified ranges
  private func filterTokensExcluding(_ tokens: [any CodeToken<MarkdownTokenElement>], ranges: [ClosedRange<Int>]) -> [any CodeToken<MarkdownTokenElement>] {
    var filteredTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    for (index, token) in tokens.enumerated() {
      let isInRange = ranges.contains { range in range.contains(index) }
      if !isInRange {
        filteredTokens.append(token)
      }
    }
    
    return filteredTokens
  }
  
  /// Build delimiter stack from punctuation tokens, excluding specified ranges
  private func buildDelimiterStack(from tokens: [any CodeToken<MarkdownTokenElement>], excludingRanges ranges: [ClosedRange<Int>]) -> [EmphasisDelimiter] {
    var delimiters: [EmphasisDelimiter] = []
    var index = 0
    
    while index < tokens.count {
      // Skip if this token is in an excluded range (e.g., code span)
      let isInExcludedRange = ranges.contains { range in range.contains(index) }
      if isInExcludedRange {
        index += 1
        continue
      }
      
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
        // Skip if this token is in an excluded range
        let isInExcludedRange = ranges.contains { range in range.contains(currentIndex) }
        if isInExcludedRange {
          break
        }
        
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
    let followingChar = getFollowingCharacter(at: index + delimiterLength, in: tokens) // Fixed: should be after the entire run
    
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
    if index >= tokens.count { return "\n" } // End of line
    
    let nextToken = tokens[index]
    if let firstChar = nextToken.text.first {
      return firstChar
    }
    return "\n"
  }
  
  /// Process emphasis using CommonMark delimiter stack algorithm
  /// This implements the official CommonMark emphasis algorithm with proper nesting
  private func processEmphasisWithDelimiterStack(tokens: [any CodeToken<MarkdownTokenElement>], delimiters: [EmphasisDelimiter]) -> [ProcessedEmphasis] {
    var processedEmphasis: [ProcessedEmphasis] = []
    var delimiterStack = delimiters
    
    // Process delimiters from left to right, finding matching pairs
    var stackIndex = 0
    while stackIndex < delimiterStack.count {
      let currentDelimiter = delimiterStack[stackIndex]
      
      // Only process closing delimiters
      guard currentDelimiter.canClose else {
        stackIndex += 1
        continue
      }
      
      // Look backwards for matching opening delimiter of same character
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
        
        // Apply the multiple of 3 rule: if one of the delimiters can both open and close,
        // then the sum of lengths must not be multiple of 3 unless both can be openers or both closers
        let totalLength = openingDelimiter.length + currentDelimiter.length
        let openerCanBoth = openingDelimiter.canOpen && openingDelimiter.canClose
        let closerCanBoth = currentDelimiter.canOpen && currentDelimiter.canClose
        
        if (openerCanBoth || closerCanBoth) && 
           totalLength % 3 == 0 && 
           !(openingDelimiter.canOpen && currentDelimiter.canOpen) &&
           !(openingDelimiter.canClose && currentDelimiter.canClose) {
          stackIndex += 1
          continue
        }
        
        // Determine how many delimiters to use
        // For proper nesting in cases like ***foo***, we need to use 2 when both sides have >=2
        let useCount: Int
        if openingDelimiter.length >= 2 && currentDelimiter.length >= 2 {
          useCount = 2  // Strong emphasis takes precedence for >=2
        } else {
          useCount = min(openingDelimiter.length, currentDelimiter.length)
        }
        
        // Calculate token positions after using delimiters
        let openingStartToken = openingDelimiter.tokenIndex + (openingDelimiter.length - useCount)
        let closingEndToken = currentDelimiter.tokenIndex + useCount - 1
        
        // Create range for the entire emphasis span (including delimiters)
        let tokenRange = openingStartToken...closingEndToken
        let isStrong = (useCount == 2)
        
        processedEmphasis.append(ProcessedEmphasis(range: tokenRange, isStrong: isStrong))
        
        // Remove processed delimiters and add remaining ones
        var newDelimiters: [EmphasisDelimiter] = Array(delimiterStack[0..<openingIndex])
        
        // Add remaining opening delimiter if any
        if openingDelimiter.length > useCount {
          let remainingOpener = EmphasisDelimiter(
            tokenIndex: openingDelimiter.tokenIndex,
            character: openingDelimiter.character,
            length: openingDelimiter.length - useCount,
            canOpen: openingDelimiter.canOpen,
            canClose: openingDelimiter.canClose
          )
          newDelimiters.append(remainingOpener)
        }
        
        // Add delimiters between opener and closer (these remain in stack)
        newDelimiters.append(contentsOf: delimiterStack[(openingIndex + 1)..<stackIndex])
        
        // Add remaining closing delimiter if any
        if currentDelimiter.length > useCount {
          let remainingCloser = EmphasisDelimiter(
            tokenIndex: currentDelimiter.tokenIndex + useCount,
            character: currentDelimiter.character,
            length: currentDelimiter.length - useCount,
            canOpen: currentDelimiter.canOpen,
            canClose: currentDelimiter.canClose
          )
          newDelimiters.append(remainingCloser)
        }
        
        // Add remaining delimiters after closer
        newDelimiters.append(contentsOf: delimiterStack[(stackIndex + 1)...])
        
        delimiterStack = newDelimiters
        
        // Restart from beginning to handle newly exposed delimiters
        stackIndex = 0
      } else {
        stackIndex += 1
      }
    }
    
    return processedEmphasis
  }
  
  /// Build node tree from tokens and processed inline elements
  private func buildNodeTree(from tokens: [any CodeToken<MarkdownTokenElement>], 
                            codeSpans: [ProcessedCodeSpan],
                            processedEmphasis: [ProcessedEmphasis],
                            processedStrikethrough: [ProcessedStrikethrough]) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var index = 0
    
    while index < tokens.count {
      // Check if this token is part of a code span (highest precedence)
      if let codeSpan = codeSpans.first(where: { $0.range.contains(index) }) {
        let content = codeSpanBuilder.extractCodeContent(from: tokens, in: codeSpan.range, backtickCount: codeSpan.backtickCount)
        let codeNode = CodeSpanNode(code: content)
        nodes.append(codeNode)
        index = codeSpan.range.upperBound + 1
        continue
      }
      
      // Check if this token is part of an emphasis range
      if let emphasis = processedEmphasis.first(where: { $0.range.contains(index) }) {
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
        continue
      }
      
      // Check if this token is part of a strikethrough range
      if let strikethrough = processedStrikethrough.first(where: { $0.range.contains(index) }) {
        let range = strikethrough.range
        
        // Skip opening ~~ delimiter (1 token)
        let contentStart = range.lowerBound + 1
        let contentEnd = range.upperBound - 1
        
        if contentStart <= contentEnd {
          let contentTokens = Array(tokens[contentStart...contentEnd])
          
          // Recursively process content
          let contentNodes = processInlineTokens(contentTokens)
          
          let strikeNode = StrikeNode(content: "")
          for child in contentNodes {
            strikeNode.append(child)
          }
          nodes.append(strikeNode)
        }
        
        // Skip to after this range
        index = range.upperBound + 1
        continue
      }
      
      // Regular token - handle different types appropriately
      let token = tokens[index]
      if token.element != .eof && token.element != .newline {
        
        // Handle line breaks (created by paragraph builder)
        if token.element == .whitespaces {
          if token.text == "__HARD_LINE_BREAK__" {
            // Hard line break (two trailing spaces + newline)
            nodes.append(LineBreakNode(variant: .hard))
          } else if token.text == "__SOFT_LINE_BREAK__" {
            // Soft line break (between lines in paragraph) 
            nodes.append(LineBreakNode(variant: .soft))
          } else {
            // Regular whitespace - add to text
            if let lastNode = nodes.last as? MarkdownText {
              lastNode.content += token.text
            } else {
              nodes.append(MarkdownText(content: token.text))
            }
          }
        } else {
          // Regular content token
          if let lastNode = nodes.last as? MarkdownText {
            // Combine with previous text node
            lastNode.content += token.text
          } else {
            // Create new text node
            nodes.append(MarkdownText(content: token.text))
          }
        }
      }
      index += 1
    }
    
    return nodes
  }
}
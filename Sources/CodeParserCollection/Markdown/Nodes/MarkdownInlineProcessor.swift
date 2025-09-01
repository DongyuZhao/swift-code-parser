import CodeParserCore
import Foundation

/// Simple inline processor for CommonMark inline elements
/// Handles basic emphasis, strong emphasis, and escaped characters
public class MarkdownInlineProcessor {
  
  public init() {}
  
  /// Process inline content from tokens and return array of inline nodes
  public func processInlineContent(_ content: String) -> [MarkdownNodeBase] {
    if content.isEmpty {
      return []
    }
    
    // For now, use simple string-based processing
    // TODO: Update to work with tokens to respect escaped content
    return parseEmphasisSimple(content)
  }
  
  /// Process inline content from tokens (respects escaped content)
  public func processInlineTokens(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var currentText = ""
    var index = 0
    
    while index < tokens.count {
      let token = tokens[index]
      
      // Handle potential emphasis markers
      if token.element == .punctuation && (token.text == "*" || token.text == "_") {
        let marker = Character(token.text)
        
        // Look for closing marker
        let (emphasisTokens, endIndex) = findEmphasisTokens(in: tokens, startingAt: index, marker: marker)
        
        if let emphasisTokens = emphasisTokens, let endIndex = endIndex {
          // Add any accumulated text first
          if !currentText.isEmpty {
            nodes.append(MarkdownText(content: currentText))
            currentText = ""
          }
          
          // Create emphasis node
          let emphasis = EmphasisNode(content: "")
          
          // Process emphasis content tokens recursively
          let emphasisContent = processInlineTokens(emphasisTokens)
          for child in emphasisContent {
            emphasis.append(child)
          }
          
          nodes.append(emphasis)
          index = endIndex
        } else {
          // No matching marker, treat as literal
          currentText += token.text
          index += 1
        }
      } else {
        // Regular token - add to current text
        currentText += token.text
        index += 1
      }
    }
    
    // Add any remaining text
    if !currentText.isEmpty {
      nodes.append(MarkdownText(content: currentText))
    }
    
    return nodes
  }
  
  /// Find matching emphasis tokens
  private func findEmphasisTokens(in tokens: [any CodeToken<MarkdownTokenElement>], startingAt start: Int, marker: Character) -> ([any CodeToken<MarkdownTokenElement>]?, Int?) {
    let markerText = String(marker)
    var searchIndex = start + 1
    
    // Look for closing marker
    while searchIndex < tokens.count {
      let token = tokens[searchIndex]
      
      if token.element == .punctuation && token.text == markerText {
        // Found closing marker
        let contentTokens = Array(tokens[(start + 1)..<searchIndex])
        return (contentTokens, searchIndex + 1)
      }
      
      searchIndex += 1
    }
    
    return (nil, nil)
  }
  
  /// Parse emphasis in content with proper flanking rules
  private func parseEmphasisSimple(_ content: String) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var currentText = ""
    var index = content.startIndex
    
    while index < content.endIndex {
      let char = content[index]
      
      // Handle emphasis markers with flanking rules
      if char == "*" || char == "_" {
        // Check if this can be a valid opening marker
        if canOpenEmphasis(in: content, at: index) {
          // Find matching closing marker
          let (emphasisContent, endIndex) = findEmphasisContent(in: content, startingAt: index, marker: char)
          
          if let emphasisContent = emphasisContent, let endIndex = endIndex {
            // Add any accumulated text first
            if !currentText.isEmpty {
              nodes.append(MarkdownText(content: currentText))
              currentText = ""
            }
            
            // Determine if it's strong or regular emphasis
            let markerCount = countMarkers(in: content, at: index, marker: char)
            let actualMarkerCount = min(markerCount, 2) // Limit to 2 for strong emphasis
            
            if actualMarkerCount >= 2 {
              // Strong emphasis
              let strong = StrongNode(content: emphasisContent)
              // Process content recursively for nested emphasis
              let inlineContent = parseEmphasisSimple(emphasisContent)
              for child in inlineContent {
                strong.append(child)
              }
              nodes.append(strong)
            } else {
              // Regular emphasis
              let emphasis = EmphasisNode(content: emphasisContent)
              // Process content recursively for nested emphasis
              let inlineContent = parseEmphasisSimple(emphasisContent)
              for child in inlineContent {
                emphasis.append(child)
              }
              nodes.append(emphasis)
            }
            
            index = endIndex
          } else {
            // No matching marker, treat as literal
            currentText.append(char)
            index = content.index(after: index)
          }
        } else {
          // Not a valid opening marker, treat as literal
          currentText.append(char)
          index = content.index(after: index)
        }
      } else {
        // Regular character
        currentText.append(char)
        index = content.index(after: index)
      }
    }
    
    // Add any remaining text
    if !currentText.isEmpty {
      nodes.append(MarkdownText(content: currentText))
    }
    
    return nodes
  }
  
  /// Check if a character at the given position can open emphasis (simplified flanking rules)
  private func canOpenEmphasis(in text: String, at index: String.Index) -> Bool {
    // Simplified rule: can open if not preceded by alphanumeric or if followed by non-whitespace
    let char = text[index]
    
    // Check what comes after
    if let nextIndex = text.index(index, offsetBy: 1, limitedBy: text.endIndex),
       nextIndex < text.endIndex {
      let nextChar = text[nextIndex]
      if nextChar.isWhitespace {
        return false // Can't open if followed by whitespace
      }
    }
    
    // For now, allow opening - real CommonMark has more complex flanking rules
    return true
  }
  
  /// Find emphasis content and return content + end index
  private func findEmphasisContent(in text: String, startingAt start: String.Index, marker: Character) -> (String?, String.Index?) {
    let markerCount = countMarkers(in: text, at: start, marker: marker)
    let contentStart = text.index(start, offsetBy: markerCount)
    
    if contentStart >= text.endIndex {
      return (nil, nil)
    }
    
    // Find closing markers
    var searchIndex = contentStart
    while searchIndex < text.endIndex {
      let char = text[searchIndex]
      
      if char == marker {
        let closingMarkerCount = countMarkers(in: text, at: searchIndex, marker: marker)
        
        // Check if we have enough closing markers and it can close
        if closingMarkerCount >= markerCount && canCloseEmphasis(in: text, at: searchIndex) {
          let contentEnd = searchIndex
          let actualEnd = text.index(searchIndex, offsetBy: min(markerCount, closingMarkerCount))
          let content = String(text[contentStart..<contentEnd])
          return (content, actualEnd)
        }
        
        // Skip past these markers
        searchIndex = text.index(searchIndex, offsetBy: closingMarkerCount)
      } else {
        searchIndex = text.index(after: searchIndex)
      }
    }
    
    return (nil, nil)
  }
  
  /// Check if a character at the given position can close emphasis (simplified flanking rules)
  private func canCloseEmphasis(in text: String, at index: String.Index) -> Bool {
    // Simplified rule: can close if not following whitespace
    if index > text.startIndex {
      let prevIndex = text.index(before: index)
      let prevChar = text[prevIndex]
      if prevChar.isWhitespace {
        return false
      }
    }
    
    return true
  }
  
  /// Count consecutive markers at given position
  private func countMarkers(in text: String, at index: String.Index, marker: Character) -> Int {
    var count = 0
    var currentIndex = index
    
    while currentIndex < text.endIndex && text[currentIndex] == marker {
      count += 1
      currentIndex = text.index(after: currentIndex)
    }
    
    return count
  }
}
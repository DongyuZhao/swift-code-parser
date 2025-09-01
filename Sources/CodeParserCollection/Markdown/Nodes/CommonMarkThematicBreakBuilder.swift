import CodeParserCore
import Foundation

/// CommonMark-compliant thematic break builder
/// Handles thematic breaks (horizontal rules) made with ***, ---, or ___
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#thematic-breaks
public class CommonMarkThematicBreakBuilder: CommonMarkBlockBuilder {
  
  public var priority: Int { return 30 }
  public var blockType: MarkdownNodeElement { return .thematicBreak }
  
  public init() {}
  
  public func canContinue(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // Thematic breaks are leaf blocks - they never continue
    return false
  }
  
  public func canStart(
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    return detectThematicBreak(in: line)
  }
  
  public func createBlock(
    from line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    guard let markerChar = extractThematicBreakMarker(from: line) else {
      return nil
    }
    
    let count = countThematicBreakChars(in: line, char: markerChar)
    let thematicBreak = ThematicBreakNode(marker: String(repeating: markerChar, count: count))
    
    return thematicBreak
  }
  
  public func processLine(
    for block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    // Thematic breaks are single-line blocks, no additional processing needed
    // Mark the entire line as consumed
    state.position = line.count
    return true
  }
  
  // MARK: - Private Helper Methods
  
  /// Detect if a line contains a thematic break pattern
  private func detectThematicBreak(in line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var index = 0
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < line.count && line[index].element == .whitespaces {
      let spaceCount = line[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Must start with a valid thematic break character
    guard index < line.count,
          line[index].element == .punctuation,
          ["*", "-", "_"].contains(line[index].text) else {
      return false
    }
    
    let thematicChar = line[index].text
    var charCount = 0
    var hasNonWhitespaceNonThematic = false
    
    while index < line.count {
      let token = line[index]
      if token.element == .punctuation && token.text == thematicChar {
        charCount += 1
        index += 1
      } else if token.element == .whitespaces {
        // Whitespace is allowed between thematic characters
        index += 1
      } else if token.element == .newline {
        // End of line - stop processing
        break
      } else {
        // Any other character makes this not a thematic break
        hasNonWhitespaceNonThematic = true
        break
      }
    }
    
    // Must have at least 3 thematic characters and no other non-whitespace content
    return charCount >= 3 && !hasNonWhitespaceNonThematic
  }
  
  /// Extract the thematic break marker character from a line
  private func extractThematicBreakMarker(from line: [any CodeToken<MarkdownTokenElement>]) -> String? {
    var index = 0
    
    // Skip leading whitespace
    while index < line.count && line[index].element == .whitespaces {
      index += 1
    }
    
    guard index < line.count,
          line[index].element == .punctuation,
          ["*", "-", "_"].contains(line[index].text) else {
      return nil
    }
    
    return line[index].text
  }
  
  /// Count the number of thematic break characters in a line
  private func countThematicBreakChars(in line: [any CodeToken<MarkdownTokenElement>], char: String) -> Int {
    var count = 0
    
    for token in line {
      if token.element == .punctuation && token.text == char {
        count += 1
      } else if token.element == .newline {
        break
      }
    }
    
    return count
  }
}
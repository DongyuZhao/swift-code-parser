import CodeParserCore
import Foundation

/// Builder for thematic breaks (---, ***, ___)
/// Implements CommonMark specification for thematic breaks (Spec 010)
public class MarkdownThematicBreakBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Thematic breaks can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    // Find the first non-whitespace token
    var firstNonWhitespaceIndex = 0
    while firstNonWhitespaceIndex < line.tokens.count {
      let token = line.tokens[firstNonWhitespaceIndex]
      if token.element != .whitespaces {
        break
      }
      firstNonWhitespaceIndex += 1
    }
    
    // Must have content after leading whitespace
    if firstNonWhitespaceIndex >= line.tokens.count {
      return false
    }
    
    let firstToken = line.tokens[firstNonWhitespaceIndex]
    
    // Must start with punctuation
    guard firstToken.element == .punctuation else {
      return false
    }
    
    // Determine the character type (must be -, *, or _)
    let thematicChar = firstToken.text
    guard thematicChar == "-" || thematicChar == "*" || thematicChar == "_" else {
      return false
    }
    
    // Count occurrences of the thematic character and verify no other characters
    var charCount = 0
    var index = firstNonWhitespaceIndex
    
    while index < line.tokens.count {
      let token = line.tokens[index]
      
      if token.element == .newline || token.element == .eof {
        // End of line
        break
      } else if token.element == .punctuation && token.text == thematicChar {
        // Matching thematic character
        charCount += 1
      } else if token.element == .whitespaces {
        // Spaces/tabs are allowed between characters
        // Continue
      } else {
        // Other characters not allowed
        return false
      }
      
      index += 1
    }
    
    // Must have at least 3 of the thematic break character
    return charCount >= 3
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // Thematic breaks are single-line blocks - they cannot continue
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    // Create thematic break node
    return MarkdownThematicBreak()
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    // Thematic breaks are single-line blocks, no processing needed
    return false
  }
}
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
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Must contain only one type of character: -, *, or _
    // Must have at least 3 of that character
    // Can have spaces between characters
    
    if content.isEmpty {
      return false
    }
    
    // Determine the character type
    let firstChar = content.first!
    guard firstChar == "-" || firstChar == "*" || firstChar == "_" else {
      return false
    }
    
    // Count occurrences of the character and verify no other characters
    var charCount = 0
    for char in content {
      if char == firstChar {
        charCount += 1
      } else if char == " " || char == "\t" {
        // Spaces/tabs are allowed
        continue
      } else {
        // Other characters not allowed
        return false
      }
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
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // Thematic breaks are single-line blocks, no processing needed
    return false
  }
}
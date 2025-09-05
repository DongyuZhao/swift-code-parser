import CodeParserCore
import Foundation

/// Builder for setext headings (underlined headings with = or -)
/// Implements CommonMark specification for setext headings (Spec 016)
public class MarkdownSetextHeadingBuilder: MarkdownBlockBuilderProtocol {
  
  private var pendingLine: MarkdownLine?
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Setext headings are detected when we see an underline (= or -)
    // Check if this could be a setext heading underline
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
    
    // Check if it's a setext heading underline character
    let underlineChar = firstToken.text
    guard underlineChar == "=" || underlineChar == "-" else {
      return false
    }
    
    // Count occurrences of the underline character and verify no other characters
    var charCount = 0
    var index = firstNonWhitespaceIndex
    
    while index < line.tokens.count {
      let token = line.tokens[index]
      
      if token.element == .newline || token.element == .eof {
        // End of line
        break
      } else if token.element == .punctuation && token.text == underlineChar {
        // Matching underline character
        charCount += 1
      } else if token.element == .whitespaces {
        // Spaces/tabs are allowed
        // Continue
      } else {
        // Other characters not allowed
        return false
      }
      
      index += 1
    }
    
    // Must have at least 1 underline character
    return charCount >= 1
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // Setext headings are single-line blocks after creation
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    // This won't be called in the current architecture
    // Setext headings need special handling in the main block builder
    return nil
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    // Setext headings don't process additional lines
    return false
  }
  
  /// Check if a line could be a setext heading underline for the given text line
  public static func isSetextUnderline(_ line: MarkdownLine, for textLine: MarkdownLine?) -> (isUnderline: Bool, level: Int) {
    guard let textLine = textLine else { return (false, 0) }
    
    // Text line cannot be indented more than 3 spaces
    if textLine.leadingWhitespace > 3 {
      return (false, 0)
    }
    
    // Text line cannot be blank
    if textLine.isBlank {
      return (false, 0)
    }
    
    // Underline cannot be indented more than 3 spaces
    if line.leadingWhitespace > 3 {
      return (false, 0)
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    if content.isEmpty {
      return (false, 0)
    }
    
    let firstChar = content.first!
    
    // Check for level 1 heading (=)
    if firstChar == "=" {
      let isValid = content.allSatisfy { char in
        char == "=" || char == " " || char == "\t"
      }
      return (isValid, 1)
    }
    
    // Check for level 2 heading (-)
    if firstChar == "-" {
      let isValid = content.allSatisfy { char in
        char == "-" || char == " " || char == "\t"
      }
      return (isValid, 2)
    }
    
    return (false, 0)
  }
  
  /// Create a setext heading from text line and underline
  public static func createSetextHeading(from textLine: MarkdownLine, level: Int) -> MarkdownHeading? {
    let content = textLine.content.trimmingCharacters(in: .whitespaces)
    
    if content.isEmpty {
      return nil
    }
    
    let heading = MarkdownHeading(level: level)
    let textNode = MarkdownText(content: content)
    heading.children.append(textNode)
    
    return heading
  }
}
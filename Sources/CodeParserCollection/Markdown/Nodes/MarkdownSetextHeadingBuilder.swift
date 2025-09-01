import CodeParserCore
import Foundation

/// Builder for setext headings (underlined headings with = or -)
/// Implements CommonMark specification for setext headings (Spec 016)
public class MarkdownSetextHeadingBuilder: MarkdownBlockBuilderProtocol {
  
  private var pendingLine: MarkdownLine?
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Setext headings need two lines, so we can't start with just one line
    // However, we can start collecting a potential heading line
    
    // Check if this could be a setext heading underline
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Check if it's a setext heading underline (= or - characters)
    if content.isEmpty {
      return false
    }
    
    let firstChar = content.first!
    if firstChar == "=" || firstChar == "-" {
      // Check if entire line consists of only = or - (with optional spaces)
      let isValidUnderline = content.allSatisfy { char in
        char == firstChar || char == " " || char == "\t"
      }
      
      if isValidUnderline {
        // This could be an underline, but we need a preceding line to be a heading
        // For now, return false - setext headings will be handled differently
        return false
      }
    }
    
    return false
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
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
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
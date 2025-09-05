import CodeParserCore
import Foundation

/// Builder for setext headings (underlined headings with = or -)
/// Implements CommonMark specification for setext headings (Spec 016)
public class MarkdownSetextHeadingBuilder: MarkdownBlockBuilderProtocol {
  
  private var pendingLine: MarkdownLine?
  public let priority: Int = 10 // High priority for transformation
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Setext headings are detected when we see an underline (= or -)
    // Check if this could be a setext heading underline
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    // Use the simpler content-based approach
    let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if content.isEmpty {
      return false
    }
    
    let firstChar = content.first!
    
    // Check if it's a valid setext underline
    if firstChar == "=" {
      return content.allSatisfy { $0 == "=" }
    } else if firstChar == "-" {
      return content.allSatisfy { $0 == "-" }
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
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    // Setext headings don't process additional lines
    return false
  }
  
  /// Check if this builder can transform an existing block (implements pluggable transformation)
  public func canTransform(block: any MarkdownBlockNode, with line: MarkdownLine) -> Bool {
    // Can only transform paragraph blocks
    guard block is ParagraphNode else { return false }
    
    // Must be a valid setext underline
    if !canStart(line: line) {
      return false
    }
    
    // Paragraph must have content
    let paragraph = block as! ParagraphNode
    if paragraph.children.isEmpty {
      return false
    }
    
    return true
  }
  
  /// Transform an existing paragraph node into a setext heading (implements AST editing)
  public func transform(block: any MarkdownBlockNode, with line: MarkdownLine) -> Bool {
    guard let paragraph = block as? ParagraphNode else { return false }
    
    // Verify this is a valid transformation
    guard canTransform(block: paragraph, with: line) else {
      return false
    }
    
    // Get the parent node so we can replace the paragraph
    guard let parent = paragraph.parent as? MarkdownNodeBase else { 
      return false 
    }
    
    // Find the index of the paragraph in its parent
    guard let paragraphIndex = parent.children.firstIndex(where: { $0 === paragraph }) else { 
      return false 
    }
    
    // Determine heading level based on underline character
    let level = line.content.trimmingCharacters(in: .whitespaces).first == "=" ? 1 : 2
    
    // Create a new heading node
    let heading = HeaderNode(level: level)
    
    // Move all children from paragraph to heading (preserves inline markup like emphasis)
    // This is the key: we don't re-parse the text, we move the existing AST nodes
    let paragraphChildren = Array(paragraph.children)
    paragraph.children.removeAll()
    for child in paragraphChildren {
      heading.append(child as! MarkdownNodeBase)
    }
    
    // Replace the paragraph with the heading in the parent
    parent.children.remove(at: paragraphIndex)
    parent.children.insert(heading, at: paragraphIndex)
    
    return true
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
    
    let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if content.isEmpty {
      return (false, 0)
    }
    
    let firstChar = content.first!
    
    // Check for level 1 heading (=)
    if firstChar == "=" {
      // Must be only = characters with optional leading/trailing spaces
      let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
      let isValid = trimmed.allSatisfy { $0 == "=" } && !trimmed.isEmpty
      return (isValid, 1)
    }
    
    // Check for level 2 heading (-)
    if firstChar == "-" {
      // Must be only - characters with optional leading/trailing spaces  
      let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
      let isValid = trimmed.allSatisfy { $0 == "-" } && !trimmed.isEmpty
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
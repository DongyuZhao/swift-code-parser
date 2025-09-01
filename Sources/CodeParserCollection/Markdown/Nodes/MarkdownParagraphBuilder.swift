import CodeParserCore
import Foundation

/// Paragraph block builder - handles regular text content
public class MarkdownParagraphBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Paragraphs can start with any non-blank line that doesn't start another block type
    return !line.isBlank && !startsWithBlockMarker(line: line)
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // Paragraphs continue until a blank line or another block marker
    guard block.blockType == "paragraph" else { return false }
    return !line.isBlank && !startsWithBlockMarker(line: line)
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard let firstToken = line.tokens.first else { return nil }
    let paragraph = ParagraphNode(range: firstToken.range)
    
    // Process the first line
    _ = processLine(block: paragraph, line: line)
    return paragraph
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let paragraph = block as? ParagraphNode else { return false }
    
    // Extract text content from the line, combining all tokens
    var textContent = ""
    for token in line.tokens {
      if token.element == .characters || token.element == .punctuation {
        textContent += token.text
      } else if token.element == .whitespaces {
        // Normalize whitespace to single spaces
        textContent += " "
      }
      // Skip newlines and EOF for now - inline processing will handle them later
    }
    
    // Add text content if not empty (normalize whitespace)
    let trimmedContent = textContent.trimmingCharacters(in: .whitespaces)
    if !trimmedContent.isEmpty {
      // Simply create a new text node - don't try to combine with existing ones for now
      let textNode = TextNode(content: trimmedContent)
      paragraph.append(textNode)
    }
    
    return true
  }
  
  public func closeBlock(block: any MarkdownBlockNode) {
    // Paragraph closing - could perform inline processing here
    // For now, this is where we'd call inline processors
  }
  
  /// Check if line starts with a block marker that would interrupt a paragraph
  private func startsWithBlockMarker(line: MarkdownLine) -> Bool {
    // For now, keep it simple - check for common block starters
    guard let firstToken = line.tokens.first else { return false }
    
    // Check for indented code block (4+ spaces)
    if firstToken.element == .whitespaces && firstToken.text.count >= 4 {
      return true
    }
    
    // Check for heading markers
    if firstToken.element == .punctuation && firstToken.text.hasPrefix("#") {
      return true
    }
    
    // Check for thematic break (---, ***, ___)
    if firstToken.element == .punctuation {
      let text = firstToken.text
      if text.hasPrefix("---") || text.hasPrefix("***") || text.hasPrefix("___") {
        return true
      }
    }
    
    return false
  }
}
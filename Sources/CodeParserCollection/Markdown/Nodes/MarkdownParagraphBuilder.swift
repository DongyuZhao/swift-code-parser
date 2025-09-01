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
    
    // Blank lines end paragraphs
    if line.isBlank { return false }
    
    // For continuation lines, we're more permissive than for starting lines
    // Only check for block markers that would definitely interrupt a paragraph
    return !startsWithInterruptingBlockMarker(line: line)
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard let firstToken = line.tokens.first else { return nil }
    let paragraph = ParagraphNode(range: firstToken.range)
    
    // Don't process the first line here - it will be processed in the main loop
    return paragraph
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let paragraph = block as? ParagraphNode else { return false }
    
    // If paragraph already has content, add a line break first
    if !paragraph.children.isEmpty {
      // Check if previous line ended with two spaces (hard line break)
      let isHardBreak = paragraph.lastLineEndedWithTwoSpaces
      let lineBreak = LineBreakNode(variant: isHardBreak ? .hard : .soft)
      paragraph.append(lineBreak)
    }
    
    // Extract text content from the line, combining all tokens
    var textContent = ""
    var endsWithTwoSpaces = false
    
    for (index, token) in line.tokens.enumerated() {
      if token.element == .characters || token.element == .punctuation {
        textContent += token.text
      } else if token.element == .whitespaces {
        // Check if this is trailing whitespace (followed only by newline/eof)
        let isTrailing = line.tokens.suffix(from: index + 1).allSatisfy { 
          $0.element == .newline || $0.element == .eof 
        }
        
        if isTrailing && token.text.count >= 2 {
          // Two or more trailing spaces = hard line break
          endsWithTwoSpaces = true
          // Don't add the trailing spaces to content
        } else {
          // Normalize other whitespace to single spaces
          textContent += " "
        }
      }
      // Skip newlines and EOF for now - inline processing will handle them later
    }
    
    // Store whether this line ended with two spaces for next line's line break
    paragraph.lastLineEndedWithTwoSpaces = endsWithTwoSpaces
    
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
    // For new paragraphs, check for common block starters
    guard let firstToken = line.tokens.first else { return false }
    
    // Check for indented code block (4+ spaces)
    if firstToken.element == .whitespaces && firstToken.text.count >= 4 {
      return true
    }
    
    // Don't check for heading markers here - let the actual heading builders decide
    // This prevents conflicts where "#5 bolt" gets marked as a block starter
    // when it should be a paragraph
    
    // Check for thematic break (---, ***, ___)
    if firstToken.element == .punctuation {
      let text = firstToken.text
      if text.hasPrefix("---") || text.hasPrefix("***") || text.hasPrefix("___") {
        return true
      }
    }
    
    return false
  }
  
  /// Check if line starts with a block marker that would interrupt a paragraph continuation
  /// This is more restrictive than startsWithBlockMarker - indented code doesn't interrupt paragraphs
  private func startsWithInterruptingBlockMarker(line: MarkdownLine) -> Bool {
    guard let firstToken = line.tokens.first else { return false }
    
    // Don't check for heading markers here either - let the actual heading builders decide
    // This prevents conflicts with lines like "#5 bolt" when they're part of a paragraph
    
    // Check for thematic break (these DO interrupt paragraphs)
    if firstToken.element == .punctuation {
      let text = firstToken.text
      if text.hasPrefix("---") || text.hasPrefix("***") || text.hasPrefix("___") {
        return true
      }
    }
    
    // NOTE: Indented code blocks (4+ spaces) do NOT interrupt paragraphs
    
    return false
  }
}
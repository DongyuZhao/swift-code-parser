import CodeParserCore
import Foundation

/// Simple token implementation for inline processing
private struct SimpleMarkdownToken: CodeToken {
  let element: MarkdownTokenElement
  let text: String
  let range: Range<String.Index>
  
  init(element: MarkdownTokenElement, text: String) {
    self.element = element
    self.text = text
    // Use a dummy range for now
    let startIndex = text.startIndex
    let endIndex = text.endIndex
    self.range = startIndex..<endIndex
  }
}

/// Paragraph block builder - handles regular text content
public class MarkdownParagraphBuilder: MarkdownBlockBuilderProtocol {
  
  private let inlineProcessor = MarkdownInlineProcessor()
  
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
    
    // Get content tokens (exclude EOF and newline)
    var contentTokens = line.tokens.filter { token in
      token.element != .eof && token.element != .newline
    }
    
    // Check for hard line break (two trailing spaces)
    var endsWithTwoSpaces = false
    if let lastToken = contentTokens.last,
       lastToken.element == .whitespaces && lastToken.text.count >= 2 {
      endsWithTwoSpaces = true
      // Remove the trailing whitespace token
      contentTokens.removeLast()
    }
    
    // If paragraph already has tokens, add a space between lines
    if !paragraph.accumulatedTokens.isEmpty {
      // Add appropriate line break token
      let lineBreakToken = createLineBreakToken(isHard: paragraph.lastLineEndedWithTwoSpaces)
      paragraph.accumulatedTokens.append(lineBreakToken)
    }
    
    // Add content tokens directly - no conversion to string!
    paragraph.accumulatedTokens.append(contentsOf: contentTokens)
    
    // Store whether this line ended with two spaces for next line's line break
    paragraph.lastLineEndedWithTwoSpaces = endsWithTwoSpaces
    
    return true
  }
  
  public func closeBlock(block: any MarkdownBlockNode) {
    // Process inline content when closing paragraph using original tokens
    guard let paragraph = block as? ParagraphNode else { return }
    
    // Clear existing children
    paragraph.children.removeAll()
    
    // Process accumulated tokens directly with inline processor
    if !paragraph.accumulatedTokens.isEmpty {
      let inlineNodes = inlineProcessor.processInlineTokens(paragraph.accumulatedTokens)
      for node in inlineNodes {
        paragraph.children.append(node)
      }
    }
  }
  
  /// Create a line break token for separating lines
  private func createLineBreakToken(isHard: Bool) -> any CodeToken<MarkdownTokenElement> {
    // Create a synthetic whitespace token to represent the line break
    let text = isHard ? "  \n" : " "
    return SimpleMarkdownToken(element: .whitespaces, text: text)
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
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
    
    // Strip leading whitespace (up to 3 spaces for paragraph indentation)
    contentTokens = stripLeadingIndentation(contentTokens, maxSpaces: 3)
    
    // Check for hard line break (two trailing spaces OR backslash at end of line)
    var endsWithHardBreak = false
    
    // Method 1: Two or more trailing spaces
    if let lastToken = contentTokens.last,
       lastToken.element == .whitespaces && lastToken.text.count >= 2 {
      endsWithHardBreak = true
      // Remove the trailing whitespace token
      contentTokens.removeLast()
    }
    
    // Method 2: Backslash at end of line (backslash should be punctuation token)
    if !endsWithHardBreak && !contentTokens.isEmpty {
      if let lastToken = contentTokens.last,
         lastToken.element == .punctuation && lastToken.text == "\\" {
        endsWithHardBreak = true
        // Remove the backslash token
        contentTokens.removeLast()
      }
    }
    
    // If paragraph already has tokens, add a line break between lines
    if !paragraph.accumulatedTokens.isEmpty {
      // Add appropriate line break token
      let lineBreakToken = createLineBreakToken(isHard: paragraph.lastLineEndedWithHardBreak)
      paragraph.accumulatedTokens.append(lineBreakToken)
    }
    
    // Add content tokens directly - no conversion to string!
    paragraph.accumulatedTokens.append(contentsOf: contentTokens)
    
    // Store whether this line ended with hard break for next line's line break
    paragraph.lastLineEndedWithHardBreak = endsWithHardBreak
    
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
    // Use special markers to distinguish from regular spaces
    let text = isHard ? "__HARD_LINE_BREAK__" : "__SOFT_LINE_BREAK__"
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
    // Thematic breaks are tokenized as individual punctuation characters
    if firstToken.element == .punctuation {
      let char = firstToken.text
      if char == "-" || char == "*" || char == "_" {
        // Count consecutive thematic break characters
        var count = 0
        for token in line.tokens {
          if token.element == .punctuation && token.text == char {
            count += 1
          } else if token.element == .whitespaces {
            // Whitespace is allowed between thematic break characters
            continue
          } else if token.element == .newline || token.element == .eof {
            // End of line
            break
          } else {
            // Other characters break the pattern
            break
          }
        }
        
        // Must have at least 3 thematic break characters
        if count >= 3 {
          return true
        }
      }
    }
    
    // NOTE: Indented code blocks (4+ spaces) do NOT interrupt paragraphs
    
    return false
  }
  
  /// Strip leading whitespace tokens (up to maxSpaces spaces) from paragraph content
  private func stripLeadingIndentation(_ tokens: [any CodeToken<MarkdownTokenElement>], maxSpaces: Int) -> [any CodeToken<MarkdownTokenElement>] {
    guard !tokens.isEmpty else { return tokens }
    
    var result = tokens
    var spacesRemoved = 0
    
    // Remove leading whitespace tokens up to maxSpaces
    while !result.isEmpty && spacesRemoved < maxSpaces {
      let firstToken = result[0]
      
      if firstToken.element == .whitespaces {
        let spaces = firstToken.text
        if spacesRemoved + spaces.count <= maxSpaces {
          // Remove entire token
          result.removeFirst()
          spacesRemoved += spaces.count
        } else {
          // Remove partial token (trim the beginning)
          let spacesToRemove = maxSpaces - spacesRemoved
          let remainingSpaces = String(spaces.dropFirst(spacesToRemove))
          if !remainingSpaces.isEmpty {
            // Create a new token with remaining spaces
            let newToken = createWhitespaceToken(remainingSpaces)
            result[0] = newToken
          } else {
            result.removeFirst()
          }
          spacesRemoved = maxSpaces
        }
      } else {
        // Hit non-whitespace, stop processing
        break
      }
    }
    
    return result
  }
  
  /// Create a whitespace token (helper for indentation stripping)
  private func createWhitespaceToken(_ content: String) -> any CodeToken<MarkdownTokenElement> {
    return SimpleMarkdownToken(element: .whitespaces, text: content)
  }
}
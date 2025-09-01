import CodeParserCore
import Foundation

/// Simple paragraph builder that follows CodeNodeBuilder pattern
/// Handles text content and creates paragraph nodes
public class ParagraphCodeNodeBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    
    // Check if current position starts text content
    if !canStartParagraph(at: context.consuming, tokens: context.tokens) {
      return false
    }
    
    // Create paragraph node
    let paragraph = ParagraphNode(range: context.tokens[context.consuming].range)
    context.current.append(paragraph)
    
    // Process content until we hit a paragraph boundary
    var hasContent = false
    var currentText = ""
    
    while context.consuming < context.tokens.count {
      let token = context.tokens[context.consuming]
      
      // Check for paragraph end conditions
      if isParagraphEnd(at: context.consuming, tokens: context.tokens) {
        break
      }
      
      // Process this token into paragraph content
      if token.element == .characters {
        currentText += token.text
        hasContent = true
        context.consuming += 1
      } else if token.element == .newline {
        // Check if this is a hard break or soft break
        let isHardBreak = isHardLineBreak(at: context.consuming, tokens: context.tokens)
        
        // Flush any accumulated text
        if !currentText.isEmpty {
          let text = TextNode(content: currentText)
          paragraph.append(text)
          currentText = ""
        }
        
        if isHardBreak {
          let lineBreak = LineBreakNode(variant: .hard)
          paragraph.append(lineBreak)
        } else {
          // Soft line break - add as soft line break if between content
          if hasContent && context.consuming + 1 < context.tokens.count && 
             !isParagraphEnd(at: context.consuming + 1, tokens: context.tokens) {
            let lineBreak = LineBreakNode(variant: .soft)
            paragraph.append(lineBreak)
          }
        }
        context.consuming += 1
      } else if token.element == .whitespaces {
        // Check if this is trailing whitespace for a hard break
        if isSignificantWhitespace(at: context.consuming, tokens: context.tokens) {
          // This is trailing whitespace for hard break - consume but don't add to text
          context.consuming += 1
        } else if isTrailingWhitespaceBeforeNewline(at: context.consuming, tokens: context.tokens) {
          // Single trailing space before newline - normalize away
          context.consuming += 1
        } else {
          // Normalize to single space
          if !currentText.isEmpty && !currentText.hasSuffix(" ") {
            currentText += " "
          }
          context.consuming += 1
        }
      } else if token.element == .punctuation {
        currentText += token.text
        hasContent = true
        context.consuming += 1
      } else if token.element == .eof {
        break
      } else {
        context.consuming += 1
      }
    }
    
    // Flush any remaining text
    if !currentText.isEmpty {
      let text = TextNode(content: currentText)
      paragraph.append(text)
    }
    
    return hasContent
  }
  
  /// Check if we can start a paragraph at the current position
  private func canStartParagraph(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return false }
    
    let token = tokens[pos]
    
    // Can start with text content
    if token.element == .characters {
      return true
    }
    
    // Can start with certain punctuation (but need to check it's not other block syntax)
    if token.element == .punctuation {
      // For now, be conservative and don't start paragraphs with punctuation
      // This could be improved to handle cases like starting with emphasis
      return false
    }
    
    return false
  }
  
  /// Check if current position indicates end of paragraph
  private func isParagraphEnd(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return true }
    
    // Check for blank line (two consecutive newlines)
    if pos + 1 < tokens.count &&
       tokens[pos].element == .newline &&
       tokens[pos + 1].element == .newline {
      return true
    }
    
    // EOF ends paragraph
    if tokens[pos].element == .eof {
      return true
    }
    
    return false
  }
  
  /// Check if newline at position should be a hard line break
  private func isHardLineBreak(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos > 0 && pos < tokens.count else { return false }
    
    // Check for backslash hard line break (backslash + newline)
    let prevToken = tokens[pos - 1]
    if prevToken.element == .punctuation && prevToken.text == "\\" {
      return true
    }
    
    // Check for trailing spaces hard line break (two or more spaces + newline)
    if prevToken.element == .whitespaces && prevToken.text.count >= 2 {
      return true
    }
    
    return false
  }
  
  /// Check if whitespace is significant (for hard line breaks)
  private func isSignificantWhitespace(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return false }
    
    let token = tokens[pos]
    if token.element != .whitespaces { return false }
    
    // Check if this whitespace is followed by a newline
    if pos + 1 < tokens.count && tokens[pos + 1].element == .newline {
      // Only 2+ spaces create hard line breaks, single space should be normalized away
      return token.text.count >= 2
    }
    
    return false
  }
  
  /// Check if this is trailing whitespace before newline that should be normalized away
  private func isTrailingWhitespaceBeforeNewline(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return false }
    
    let token = tokens[pos]
    if token.element != .whitespaces { return false }
    
    // Check if this whitespace is followed by a newline and is single space
    if pos + 1 < tokens.count && tokens[pos + 1].element == .newline {
      return token.text.count == 1
    }
    
    return false
  }
}
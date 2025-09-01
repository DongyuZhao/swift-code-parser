import CodeParserCore
import Foundation

/// Simple indented code block builder that follows CodeNodeBuilder pattern
/// Handles 4+ space indented code blocks  
public class IndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    
    // Check if current position starts an indented code block (4+ spaces)
    if !canStartIndentedCodeBlock(at: context.consuming, tokens: context.tokens) {
      return false
    }
    
    // Collect all the code content
    var codeContent = ""
    var hasContent = false
    
    while context.consuming < context.tokens.count {
      // Check if this line starts with 4+ spaces (continuation) or is blank
      if isIndentedCodeLine(at: context.consuming, tokens: context.tokens) {
        // Process this line as code content
        let lineContent = consumeCodeLine(from: context.consuming, tokens: context.tokens)
        context.consuming += lineContent.consumedTokens
        
        if !lineContent.content.isEmpty {
          if hasContent {
            codeContent += "\n"
          }
          codeContent += lineContent.content
          hasContent = true
        } else if hasContent {
          // Blank line within code block
          codeContent += "\n"
        }
      } else {
        // Line doesn't continue the code block
        break
      }
    }
    
    // Create the code block if we found content
    if hasContent {
      let codeBlock = CodeBlockNode(source: codeContent)
      context.current.append(codeBlock)
      return true
    }
    
    return false
  }
  
  /// Check if we can start an indented code block at current position
  private func canStartIndentedCodeBlock(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return false }
    
    // Must start with 4+ spaces
    let token = tokens[pos]
    if token.element == .whitespaces && token.text.count >= 4 {
      return true
    }
    
    return false
  }
  
  /// Check if current position is an indented code line (4+ spaces or blank)
  private func isIndentedCodeLine(at pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard pos < tokens.count else { return false }
    
    let token = tokens[pos]
    
    // Line with 4+ spaces of indentation
    if token.element == .whitespaces && token.text.count >= 4 {
      return true
    }
    
    // Blank line (just newline)
    if token.element == .newline {
      return true
    }
    
    return false
  }
  
  /// Consume a code line and return content + number of tokens consumed
  private func consumeCodeLine(from pos: Int, tokens: [any CodeToken<MarkdownTokenElement>]) -> (content: String, consumedTokens: Int) {
    var content = ""
    var tokensConsumed = 0
    var index = pos
    
    // Handle leading indentation
    if index < tokens.count && tokens[index].element == .whitespaces {
      let whitespace = tokens[index].text
      if whitespace.count >= 4 {
        // Remove 4 spaces of indentation, keep the rest
        let remaining = String(whitespace.dropFirst(4))
        if !remaining.isEmpty {
          content += remaining
        }
      }
      index += 1
      tokensConsumed += 1
    }
    
    // Consume rest of line until newline
    while index < tokens.count {
      let token = tokens[index]
      
      if token.element == .newline {
        tokensConsumed += 1
        break
      } else if token.element == .eof {
        break
      } else {
        content += token.text
        index += 1
        tokensConsumed += 1
      }
    }
    
    return (content, tokensConsumed)
  }
}
import CodeParserCore
import Foundation

/// Handles indented code block creation following CommonMark spec
/// Indented code blocks are lines indented by 4+ spaces or 1+ tabs
public class MarkdownIndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard !context.tokens.isEmpty else { return false }
    
    // Close any open paragraph when we encounter an indented code block
    if context.current is ParagraphNode {
      if let parent = context.current.parent {
        context.current = parent
      }
    }
    
    // Check for proper indentation (4+ spaces or 1+ tabs)
    guard let indentationInfo = getIndentationInfo(context.tokens) else { return false }
    
    if !indentationInfo.isCodeBlock {
      return false
    }
    
    // Check if we're continuing an existing code block
    if let existingCodeBlock = context.current as? CodeBlockNode {
      // Add this line to the existing code block with proper newline handling
      let lineContent = extractCodeContent(context.tokens, removeSpaces: min(4, indentationInfo.spaces))
      existingCodeBlock.source += "\n" + lineContent
      
      context.consuming = context.tokens.count
      return true
    }
    
    // Create new indented code block
    let lineContent = extractCodeContent(context.tokens, removeSpaces: min(4, indentationInfo.spaces))
    let codeBlock = CodeBlockNode(source: lineContent)
    
    context.current.append(codeBlock)
    context.current = codeBlock
    
    context.consuming = context.tokens.count
    return true
  }
  
  private struct IndentationInfo {
    let spaces: Int
    let tabs: Int
    let isCodeBlock: Bool
  }
  
  private func getIndentationInfo(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> IndentationInfo? {
    guard let firstToken = tokens.first else { return nil }
    
    var spaces = 0
    var tabs = 0
    
    if firstToken.element == .whitespaces {
      for char in firstToken.text {
        if char == " " {
          spaces += 1
        } else if char == "\t" {
          tabs += 1
        }
      }
    }
    
    // A line is a code block if:
    // - It has 4+ spaces, or
    // - It has 1+ tabs, or
    // - It has 1-3 spaces followed by a tab
    let isCodeBlock = spaces >= 4 || tabs >= 1
    
    return IndentationInfo(spaces: spaces, tabs: tabs, isCodeBlock: isCodeBlock)
  }
  
  private func extractCodeContent(_ tokens: [any CodeToken<MarkdownTokenElement>], removeSpaces: Int) -> String {
    var result = ""
    var spacesToRemove = removeSpaces
    
    for token in tokens {
      if token.element == .newline || token.element == .eof {
        break
      } else if token.element == .whitespaces && spacesToRemove > 0 {
        // Remove leading indentation
        var remainingSpaces = spacesToRemove
        for char in token.text {
          if char == " " && remainingSpaces > 0 {
            remainingSpaces -= 1
          } else if char == "\t" && remainingSpaces > 0 {
            remainingSpaces = 0 // Tab removes all remaining spaces
          } else {
            result.append(char)
          }
        }
        spacesToRemove = 0
      } else {
        result += token.text
      }
    }
    
    return result
  }
}
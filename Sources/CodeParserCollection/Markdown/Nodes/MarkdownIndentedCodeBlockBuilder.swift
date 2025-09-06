import CodeParserCore
import Foundation

/// Indented code block builder - handles 4+ space indented code blocks
public class MarkdownIndentedCodeBlockBuilder: MarkdownBlockBuilderProtocol {
  
  public let priority: Int = 80 // Low priority
  
  public init() {}
  
  public func canHandle(block: any MarkdownBlockNode) -> Bool {
    return block.blockType == "code_block"
  }
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Indented code blocks start with 4+ spaces followed by non-whitespace
    return line.leadingWhitespace >= 4 && hasNonWhitespaceContent(line: line)
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard block.blockType == "code_block" else { return false }
    
    // Code blocks continue with:
    // 1. Lines with 4+ spaces of indentation
    // 2. Blank lines (they can be part of the code block)
    return line.leadingWhitespace >= 4 || line.isBlank
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard !line.tokens.isEmpty else { return nil }
    
    let codeBlock = CodeBlockNode(source: "", language: nil)
    
    // Don't process the first line here - it will be processed in the main loop
    return codeBlock
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    guard let codeBlock = block as? CodeBlockNode else { return false }
    
    if line.isBlank {
      // Blank line - add to code content
      if !codeBlock.source.isEmpty {
        codeBlock.source += "\n"
      }
      return true
    }
    
    // Extract code content, removing 4 spaces worth of indentation (with tab expansion)
    var codeContent = ""
    var remainingIndent = 4
    var column = 0  // Track column position for tab expansion
    
    for token in line.tokens {
      if token.element == .whitespaces && remainingIndent > 0 {
        let whitespaceText = token.text
        
        // Process character by character to handle tab expansion
        for char in whitespaceText {
          if remainingIndent <= 0 {
            // No more indentation to consume, add to content
            codeContent += String(char)
            continue
          }
          
          if char == "\t" {
            // Tab expands to next 4-character boundary
            let spacesToAdd = 4 - (column % 4)
            if spacesToAdd <= remainingIndent {
              // Consume entire tab as indentation
              remainingIndent -= spacesToAdd
              column += spacesToAdd
            } else {
              // Partially consume tab, add remaining spaces to content
              let remainingSpaces = spacesToAdd - remainingIndent
              codeContent += String(repeating: " ", count: remainingSpaces)
              remainingIndent = 0
              column += spacesToAdd
            }
          } else {
            // Regular space character
            remainingIndent -= 1
            column += 1
          }
        }
      } else if token.element != .newline && token.element != .eof {
        // Add all other content (except newlines, which are implied)
        codeContent += token.text
      }
    }
    
    // Add the line to the code block
    if !codeBlock.source.isEmpty {
      codeBlock.source += "\n"
    }
    codeBlock.source += codeContent
    
    return true
  }
  
  public func closeBlock(block: any MarkdownBlockNode) {
    guard let codeBlock = block as? CodeBlockNode else { return }
    
    // Remove trailing empty lines from code content
    codeBlock.source = codeBlock.source.trimmingCharacters(in: .newlines)
  }
  
  /// Check if line has non-whitespace content after leading whitespace
  private func hasNonWhitespaceContent(line: MarkdownLine) -> Bool {
    var foundContent = false
    var skipWhitespace = true
    
    for token in line.tokens {
      if skipWhitespace && token.element == .whitespaces {
        continue
      }
      skipWhitespace = false
      
      if token.element != .newline && token.element != .eof {
        foundContent = true
        break
      }
    }
    
    return foundContent
  }
}
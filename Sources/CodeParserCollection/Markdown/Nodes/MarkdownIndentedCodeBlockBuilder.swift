import CodeParserCore
import Foundation

/// Indented code block builder - handles 4+ space indented code blocks
public class MarkdownIndentedCodeBlockBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
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
    
    // Process the first line
    _ = processLine(block: codeBlock, line: line)
    return codeBlock
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let codeBlock = block as? CodeBlockNode else { return false }
    
    if line.isBlank {
      // Blank line - add to code content
      if !codeBlock.source.isEmpty {
        codeBlock.source += "\n"
      }
      return true
    }
    
    // Extract code content, removing 4 spaces of indentation
    var codeContent = ""
    var remainingIndent = 4
    
    for token in line.tokens {
      if token.element == .whitespaces && remainingIndent > 0 {
        let spaces = token.text
        if spaces.count <= remainingIndent {
          // Consume all this whitespace as indentation
          remainingIndent -= spaces.count
        } else {
          // Keep extra whitespace beyond 4 spaces
          let extraSpaces = String(spaces.dropFirst(remainingIndent))
          codeContent += extraSpaces
          remainingIndent = 0
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
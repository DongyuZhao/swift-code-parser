import CodeParserCore
import Foundation

/// Builder for blockquotes (> quoted text)
/// Implements CommonMark specification for blockquotes (Spec 024)
public class MarkdownBlockquoteBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Blockquotes can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Must start with '>' character
    return content.hasPrefix(">")
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard block.blockType == "blockquote" else { return false }
    
    // Blockquotes can continue with lines that start with '>'
    // or with lazy continuation (lines without '>')
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Can continue with '>' lines
    if content.hasPrefix(">") {
      return true
    }
    
    // Can continue with lazy continuation (non-blank lines)
    if !line.isBlank {
      return true
    }
    
    // Blank lines generally end blockquotes
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    let blockquote = MarkdownBlockquote(level: 1)
    
    // Process the initial line
    _ = processLine(block: blockquote, line: line)
    
    return blockquote
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let blockquote = block as? MarkdownBlockquote else { return false }
    
    // Extract content after the '>' marker
    let content = line.content.trimmingCharacters(in: .whitespaces)
    var blockquoteContent = ""
    
    if content.hasPrefix(">") {
      // Remove the '>' marker
      blockquoteContent = String(content.dropFirst())
      
      // Remove optional space after '>'
      if blockquoteContent.hasPrefix(" ") || blockquoteContent.hasPrefix("\t") {
        blockquoteContent = String(blockquoteContent.dropFirst())
      }
    } else {
      // Lazy continuation - use the entire line
      blockquoteContent = content
    }
    
    // Create a paragraph to hold the content
    // In a proper implementation, we'd need to recursively parse blockquote content
    // For now, create a simple paragraph structure
    let currentParagraph: MarkdownParagraph
    
    if let lastChild = blockquote.children.last as? MarkdownParagraph {
      // Continue existing paragraph
      currentParagraph = lastChild
    } else {
      // Create new paragraph
      currentParagraph = MarkdownParagraph(range: blockquoteContent.startIndex..<blockquoteContent.endIndex)
      blockquote.children.append(currentParagraph)
    }
    
    // Add content to the paragraph
    if !blockquoteContent.isEmpty {
      let textNode = MarkdownText(content: blockquoteContent)
      currentParagraph.children.append(textNode)
    }
    
    return true
  }
}
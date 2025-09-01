import CodeParserCore
import Foundation

/// Builder for list items (- item, * item, + item, 1. item, etc.)
/// Implements CommonMark specification for list items (Spec 025)
public class MarkdownListItemBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // List items can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Check for unordered list markers (-, *, +)
    if content.hasPrefix("-") || content.hasPrefix("*") || content.hasPrefix("+") {
      let afterMarker = content.dropFirst()
      // Must be followed by space, tab, or end of line
      if afterMarker.isEmpty || afterMarker.first == " " || afterMarker.first == "\t" {
        return true
      }
    }
    
    // Check for ordered list markers (1., 2., etc.)
    if let match = content.range(of: #"^\d{1,9}[.)]"#, options: .regularExpression) {
      let afterMarker = content[match.upperBound...]
      // Must be followed by space, tab, or end of line
      if afterMarker.isEmpty || afterMarker.first == " " || afterMarker.first == "\t" {
        return true
      }
    }
    
    return false
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard block.blockType == "list_item" else { return false }
    
    // List items can continue with indented lines or blank lines
    // This is complex and depends on the list item's content indent
    
    // For now, simple continuation logic
    if line.isBlank {
      return true // Blank lines can be part of list items
    }
    
    // Non-blank lines can continue if properly indented
    // For simplicity, allow any non-blank line that doesn't start a new list item
    return !canStart(line: line)
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Extract marker
    var marker = ""
    var contentAfterMarker = ""
    
    if content.hasPrefix("-") || content.hasPrefix("*") || content.hasPrefix("+") {
      marker = String(content.first!)
      contentAfterMarker = String(content.dropFirst())
    } else if let match = content.range(of: #"^\d{1,9}[.)]"#, options: .regularExpression) {
      marker = String(content[match])
      contentAfterMarker = String(content[match.upperBound...])
    }
    
    let listItem = MarkdownListItem(marker: marker)
    
    // Process the content after marker
    _ = processLine(block: listItem, line: line)
    
    return listItem
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let listItem = block as? MarkdownListItem else { return false }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // For the first line, extract content after marker
    var itemContent = ""
    if listItem.children.isEmpty {
      // First line - extract content after marker
      if content.hasPrefix("-") || content.hasPrefix("*") || content.hasPrefix("+") {
        itemContent = String(content.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
      } else if let match = content.range(of: #"^\d{1,9}[.)]"#, options: .regularExpression) {
        itemContent = String(content[match.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
      }
    } else {
      // Continuation line
      itemContent = content
    }
    
    // Add content to list item
    if !itemContent.isEmpty {
      // Create a paragraph for the content
      let paragraph = MarkdownParagraph(range: itemContent.startIndex..<itemContent.endIndex)
      let textNode = MarkdownText(content: itemContent)
      paragraph.children.append(textNode)
      listItem.children.append(paragraph)
    }
    
    return true
  }
}
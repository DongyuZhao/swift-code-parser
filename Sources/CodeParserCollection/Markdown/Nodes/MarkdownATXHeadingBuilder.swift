import CodeParserCore
import Foundation

/// Builder for ATX headings (# heading, ## heading, etc.)
/// Implements CommonMark specification for ATX headings (Spec 011)
public class MarkdownATXHeadingBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // ATX headings can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    // Find first non-whitespace content
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Must start with 1-6 # characters
    let hashCount = content.prefix { $0 == "#" }.count
    if hashCount < 1 || hashCount > 6 {
      return false
    }
    
    // After the hashes, must be either end of line or space/tab
    if content.count == hashCount {
      return true // Just hashes, valid empty heading
    }
    
    let afterHashes = content.dropFirst(hashCount)
    return afterHashes.first == " " || afterHashes.first == "\t"
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // ATX headings are single-line blocks - they cannot continue
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Extract level (number of # characters)
    let level = content.prefix { $0 == "#" }.count
    guard level >= 1 && level <= 6 else { return nil }
    
    // Extract content after the hashes
    var headingContent = String(content.dropFirst(level))
    
    // Remove leading whitespace
    headingContent = headingContent.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
    
    // Remove optional closing sequence (trailing # characters)
    headingContent = removeClosingSequence(from: headingContent)
    
    // Create heading node
    let heading = MarkdownHeading(level: level)
    
    // Add content as text node if not empty
    if !headingContent.isEmpty {
      let textNode = MarkdownText(content: headingContent)
      heading.children.append(textNode)
    }
    
    return heading
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // ATX headings are single-line blocks, no processing needed
    return false
  }
  
  /// Remove optional closing sequence of # characters from the end
  private func removeClosingSequence(from content: String) -> String {
    var result = content
    
    // Remove trailing whitespace first, but keep track of it
    let trimmedResult = result.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
    
    // Check if it ends with # characters
    var endIndex = trimmedResult.endIndex
    var hasClosingSequence = false
    
    // Find the last non-# character
    while endIndex > trimmedResult.startIndex {
      let prevIndex = trimmedResult.index(before: endIndex)
      if trimmedResult[prevIndex] == "#" {
        hasClosingSequence = true
        endIndex = prevIndex
      } else {
        break
      }
    }
    
    if hasClosingSequence && endIndex > trimmedResult.startIndex {
      // If we found closing #s and there's content before them
      let beforeClosing = String(trimmedResult[..<endIndex])
      
      // Check if the content before closing hashes ends with space/tab
      if beforeClosing.last == " " || beforeClosing.last == "\t" {
        // Valid closing sequence - remove it and any trailing spaces
        result = beforeClosing.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
      } else {
        // No space before closing hashes - they're part of content
        result = trimmedResult
      }
    } else if hasClosingSequence && endIndex == trimmedResult.startIndex {
      // Only # characters, return empty
      result = ""
    } else {
      // No closing sequence
      result = trimmedResult
    }
    
    return result
  }
}
import CodeParserCore
import Foundation

/// Builder for ATX headings (# heading, ## heading, etc.)
/// Implements CommonMark specification for ATX headings (Spec 011)
public class MarkdownATXHeadingBuilder: MarkdownBlockBuilderProtocol {
  
  private let inlineProcessor = MarkdownInlineProcessor()
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // ATX headings can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    // Find first non-whitespace content (excluding potential trailing newlines/eof)
    let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Handle escaped hash at start
    if content.hasPrefix("\\#") {
      return false // Escaped hash doesn't start a heading
    }
    
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
    let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Handle escaped hash at start - should not create heading
    if content.hasPrefix("\\#") {
      return nil
    }
    
    // Extract level (number of # characters)
    let level = content.prefix { $0 == "#" }.count
    guard level >= 1 && level <= 6 else { return nil }
    
    // Create heading node
    let heading = MarkdownHeading(level: level)
    
    // Extract content tokens after the hashes and whitespace
    let contentTokens = extractContentTokens(from: line.tokens, level: level)
    
    // Process content with inline elements if not empty
    if !contentTokens.isEmpty {
      let inlineNodes = inlineProcessor.processInlineTokens(contentTokens)
      for node in inlineNodes {
        heading.children.append(node)
      }
    }
    
    return heading
  }
  
  /// Extract content tokens after hash markers and leading whitespace
  private func extractContentTokens(from tokens: [any CodeToken<MarkdownTokenElement>], level: Int) -> [any CodeToken<MarkdownTokenElement>] {
    var resultTokens: [any CodeToken<MarkdownTokenElement>] = []
    var hashCount = 0
    var index = 0
    
    // Skip hash tokens
    while index < tokens.count && hashCount < level {
      let token = tokens[index]
      if token.element == .punctuation && token.text == "#" {
        hashCount += 1
        index += 1
      } else {
        break
      }
    }
    
    // Skip one whitespace token if present
    if index < tokens.count && tokens[index].element == .whitespaces {
      index += 1
    }
    
    // Collect remaining tokens (except EOF)
    while index < tokens.count {
      let token = tokens[index]
      if token.element != .eof && token.element != .newline {
        resultTokens.append(token)
      }
      index += 1
    }
    
    // Remove closing sequence tokens if present
    return removeClosingSequenceTokens(from: resultTokens)
  }
  
  /// Remove closing sequence tokens from the end
  private func removeClosingSequenceTokens(from tokens: [any CodeToken<MarkdownTokenElement>]) -> [any CodeToken<MarkdownTokenElement>] {
    // Simple approach: remove trailing hash punctuation tokens if preceded by whitespace
    var result = tokens
    
    // Work backwards to find trailing hash tokens
    while !result.isEmpty {
      let lastToken = result.last!
      if lastToken.element == .punctuation && lastToken.text == "#" {
        result.removeLast()
        
        // Check if preceded by whitespace - if so, remove the whitespace too
        if !result.isEmpty && result.last!.element == .whitespaces {
          result.removeLast()
        }
      } else {
        break
      }
    }
    
    return result
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // ATX headings are single-line blocks, no processing needed
    return false
  }
  
  /// Remove optional closing sequence of # characters from the end
  /// Handles escaped # characters properly per CommonMark spec
  private func removeClosingSequence(from content: String) -> String {
    var result = content
    
    // Remove trailing whitespace first, but keep track of it
    let trimmedResult = result.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
    
    if trimmedResult.isEmpty {
      return ""
    }
    
    // Check if it ends with # characters, but handle escapes
    var endIndex = trimmedResult.endIndex
    var hasClosingSequence = false
    var hashCount = 0
    
    // Find the last non-# character, but skip escaped hashes
    while endIndex > trimmedResult.startIndex {
      let prevIndex = trimmedResult.index(before: endIndex)
      let char = trimmedResult[prevIndex]
      
      if char == "#" {
        // Check if this hash is escaped
        var isEscaped = false
        if prevIndex > trimmedResult.startIndex {
          let beforePrevIndex = trimmedResult.index(before: prevIndex)
          if trimmedResult[beforePrevIndex] == "\\" {
            isEscaped = true
          }
        }
        
        if isEscaped {
          // Escaped hash - not part of closing sequence
          break
        } else {
          hasClosingSequence = true
          hashCount += 1
          endIndex = prevIndex
        }
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
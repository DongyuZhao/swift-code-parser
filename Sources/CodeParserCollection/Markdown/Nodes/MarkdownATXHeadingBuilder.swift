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
    
    // Check tokens directly for escaped content
    var hashCount = 0
    var tokenIndex = 0
    
    // Skip leading whitespace token
    if tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    // Check for escaped hash at start
    if tokenIndex < line.tokens.count {
      let token = line.tokens[tokenIndex]
      // If it's a characters token starting with #, it was likely escaped
      if token.element == .characters && token.text.hasPrefix("#") {
        return false
      }
    }
    
    // Count hash tokens
    while tokenIndex < line.tokens.count {
      let token = line.tokens[tokenIndex]
      if token.element == .punctuation && token.text == "#" {
        hashCount += 1
        tokenIndex += 1
      } else {
        break
      }
    }
    
    // Must have 1-6 # characters
    if hashCount < 1 || hashCount > 6 {
      return false
    }
    
    // After the hashes, must be either end of line or whitespace
    if tokenIndex >= line.tokens.count {
      return true // Just hashes at end of line, valid empty heading
    }
    
    // Check next token after hashes
    let nextToken = line.tokens[tokenIndex]
    if nextToken.element == .whitespaces || nextToken.element == .newline || nextToken.element == .eof {
      return true
    }
    
    // If next token is not whitespace, it's not a valid heading
    return false
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // ATX headings are single-line blocks - they cannot continue
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    // Extract level by counting hash tokens
    var level = 0
    var tokenIndex = 0
    
    // Skip leading whitespace token
    if tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    // Count hash tokens
    while tokenIndex < line.tokens.count {
      let token = line.tokens[tokenIndex]
      if token.element == .punctuation && token.text == "#" {
        level += 1
        tokenIndex += 1
      } else {
        break
      }
    }
    
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
    var result = tokens
    
    // Work backwards to find trailing hash tokens
    var foundClosingHashes = false
    var trailingHashCount = 0
    
    // First pass: count trailing hashes
    var index = result.count - 1
    while index >= 0 {
      let token = result[index]
      if token.element == .punctuation && token.text == "#" {
        trailingHashCount += 1
        foundClosingHashes = true
        index -= 1
      } else if token.element == .whitespaces && foundClosingHashes {
        // Whitespace before closing hashes
        index -= 1
        break
      } else {
        // Non-hash, non-whitespace token
        break
      }
    }
    
    // If we found closing hashes and there's content before them with whitespace
    if foundClosingHashes && index >= 0 && trailingHashCount > 0 {
      // Check if the content before the whitespace and hashes is valid
      let beforeWhitespace = index
      if beforeWhitespace >= 0 {
        // Remove the trailing hashes and the whitespace before them
        let removeCount = trailingHashCount + 1 // +1 for whitespace
        let newCount = max(0, result.count - removeCount)
        result = Array(result[0..<newCount])
      }
    } else if foundClosingHashes && index < 0 {
      // Only hashes, remove all
      result = []
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
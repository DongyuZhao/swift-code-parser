import CodeParserCore
import Foundation

/// Handles ATX heading creation following CommonMark spec
/// ATX headings start with 1-6 # characters followed by space and content
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard !context.tokens.isEmpty else { return false }
    
    // Close any open paragraph when we encounter a heading
    if context.current is ParagraphNode {
      if let parent = context.current.parent {
        context.current = parent
      }
    }
    
    var index = 0
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < context.tokens.count && context.tokens[index].element == .whitespaces {
      leadingSpaces += context.tokens[index].text.count
      if leadingSpaces > 3 {
        return false // Too much indentation for ATX heading
      }
      index += 1
    }
    
    guard index < context.tokens.count else { return false }
    
    // Check for opening # sequence
    let hashToken = context.tokens[index]
    guard hashToken.element == .punctuation && hashToken.text.first == "#" else {
      return false
    }
    
    // Count # characters (must be 1-6)
    let level = hashToken.text.count
    guard level >= 1 && level <= 6 else { return false }
    
    index += 1
    
    // Must be followed by space or end of line for valid ATX heading
    var hasSpace = false
    if index < context.tokens.count {
      let nextToken = context.tokens[index]
      if nextToken.element == .whitespaces {
        hasSpace = true
        index += 1
      } else if nextToken.element == .newline || nextToken.element == .eof {
        // Empty heading is valid
        hasSpace = true
      } else {
        return false // No space after #
      }
    } else {
      hasSpace = true // End of tokens means empty heading
    }
    
    // Collect content tokens (everything except newline/eof)
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    while index < context.tokens.count {
      let token = context.tokens[index]
      if token.element == .newline || token.element == .eof {
        break
      }
      contentTokens.append(token)
      index += 1
    }
    
    // Remove trailing # and whitespace from content (closing sequence)
    contentTokens = removeTrailingHashSequence(contentTokens)
    
    // Create heading node
    let heading = HeaderNode(level: level)
    context.current.append(heading)
    
    // Create ContentNode if there's content
    if !contentTokens.isEmpty {
      let contentNode = ContentNode(tokens: contentTokens)
      heading.append(contentNode)
    }
    
    // Don't change context.current to heading - headings are leaf containers
    // that close immediately
    
    context.consuming = context.tokens.count
    return true
  }
  
  private func removeTrailingHashSequence(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [any CodeToken<MarkdownTokenElement>] {
    var result = tokens
    
    // Remove trailing whitespace
    while let last = result.last, last.element == .whitespaces {
      result.removeLast()
    }
    
    // Remove trailing # sequence (must be preceded by space to be valid closing)
    var hasTrailingHash = false
    if let last = result.last, last.element == .punctuation && last.text.first == "#" {
      hasTrailingHash = true
      result.removeLast()
      
      // Remove any additional # tokens
      while let last = result.last, last.element == .punctuation && last.text.first == "#" {
        result.removeLast()
      }
      
      // The closing # sequence must be preceded by whitespace or be the only content
      if let last = result.last, last.element != .whitespaces && !result.isEmpty {
        // Not preceded by whitespace, so the # characters are part of content
        // We need to restore them
        let hashText = String(repeating: "#", count: tokens.count - result.count)
        let hashRange = tokens[result.count].range
        let hashToken = MarkdownToken(element: .punctuation, text: hashText, range: hashRange)
        result.append(hashToken)
        return result
      }
      
      // Remove the preceding whitespace if it exists
      if let last = result.last, last.element == .whitespaces {
        result.removeLast()
      }
    }
    
    return result
  }
}
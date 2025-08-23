import CodeParserCore
import Foundation

/// Handles ATX headings (# through ######)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#atx-headings
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    // Skip if we're not at the beginning of a line or after processed tokens
    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check for opening hash sequence
    var hashCount = 0
    var currentIndex = startIndex

    // Count consecutive # characters
    while currentIndex < context.tokens.count,
          let token = context.tokens[currentIndex] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == "#" {
      hashCount += 1
      currentIndex += 1
      
      // ATX headings support levels 1-6 only
      if hashCount > 6 {
        return false
      }
    }

    // Must have at least one # and at most 6
    guard hashCount >= 1 && hashCount <= 6 else {
      return false
    }

    // Check what follows the hashes
    if currentIndex >= context.tokens.count {
      // End of line - valid heading with empty content
    } else if let nextToken = context.tokens[currentIndex] as? any CodeToken<MarkdownTokenElement>,
              nextToken.element == .whitespaces {
      // Space after hashes - consume it
      currentIndex += 1
    } else {
      // No space and not end of line - not a valid ATX heading
      return false
    }

    // Create heading node
    let heading = HeaderNode(level: hashCount)
    context.current.append(heading)

    // Collect content tokens (everything after opening sequence, excluding newline)
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    
    // Find end of content (before newline or EOF)
    var contentEnd = context.tokens.count
    for i in currentIndex..<context.tokens.count {
      if context.tokens[i].element == .newline {
        contentEnd = i
        break
      }
    }
    
    if currentIndex < contentEnd {
      let remainingTokens = Array(context.tokens[currentIndex..<contentEnd])
      
      // Look for trailing hash sequence (optional closing)
      var trailingHashStart = remainingTokens.count
      var i = remainingTokens.count - 1
      
      // Skip trailing # characters from the end
      while i >= 0,
            remainingTokens[i].element == .punctuation,
            remainingTokens[i].text == "#" {
        trailingHashStart = i
        i -= 1
      }
      
      // If we found trailing hashes, check if they're preceded by whitespace
      if trailingHashStart < remainingTokens.count {
        if trailingHashStart == 0 {
          // All remaining content is hashes - empty heading
          contentTokens = []
        } else if remainingTokens[trailingHashStart - 1].element == .whitespaces {
          // Whitespace before trailing hashes - remove the whitespace and hashes
          contentTokens = Array(remainingTokens[0..<(trailingHashStart - 1)])
        } else {
          // No whitespace before hashes - they're part of content
          contentTokens = remainingTokens
        }
      } else {
        // No trailing hashes
        contentTokens = remainingTokens
      }
    }

    // Add content to heading
    if !contentTokens.isEmpty {
      let contentNode = ContentNode(tokens: contentTokens)
      heading.append(contentNode)
    }

    return true
  }
}
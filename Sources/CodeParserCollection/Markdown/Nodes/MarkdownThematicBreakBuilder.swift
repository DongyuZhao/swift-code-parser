import CodeParserCore
import Foundation

/// Handles thematic breaks (horizontal rules) made with ***, ---, or ___
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#thematic-breaks
public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    var index = startIndex
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < context.tokens.count,
          let token = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      let spaceCount = token.text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Must start with a valid thematic break character
    guard index < context.tokens.count else { return false }
    
    let thematicChar: String
    if let firstToken = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
       firstToken.element == .punctuation {
      switch firstToken.text {
      case "*", "-", "_":
        thematicChar = firstToken.text
      default:
        return false
      }
    } else {
      return false
    }
    
    // Count occurrences of the thematic character, allowing whitespace in between
    var charCount = 0
    var hasNonWhitespaceNonThematic = false
    
    while index < context.tokens.count {
      let token = context.tokens[index]
      
      if token.element == .punctuation && token.text == thematicChar {
        charCount += 1
        index += 1
      } else if token.element == .whitespaces {
        // Whitespace is allowed between thematic characters
        index += 1
      } else if token.element == .newline {
        // End of line - stop processing
        break
      } else {
        // Any other character makes this not a thematic break
        hasNonWhitespaceNonThematic = true
        break
      }
    }
    
    // Must have at least 3 thematic characters and no other non-whitespace content
    guard charCount >= 3 && !hasNonWhitespaceNonThematic else {
      return false
    }
    
    // Create thematic break
    let thematicBreak = ThematicBreakNode(marker: String(repeating: thematicChar, count: charCount))
    context.current.append(thematicBreak)

    return true
  }
}
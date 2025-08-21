import CodeParserCore
import Foundation

/// Handles thematic break creation following CommonMark spec
/// Thematic breaks are lines with 3+ -, *, or _ characters (possibly separated by spaces)
public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard !context.tokens.isEmpty else { return false }
    
    // Close any open paragraph when we encounter a thematic break
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
        return false // Too much indentation for thematic break
      }
      index += 1
    }
    
    guard index < context.tokens.count else { return false }
    
    // Check for thematic break character (-, *, _)
    let firstToken = context.tokens[index]
    guard firstToken.element == .punctuation else { return false }
    
    let char = firstToken.text.first!
    guard char == "-" || char == "*" || char == "_" else { return false }
    
    // Count occurrences of the character, allowing whitespace in between
    var charCount = 0
    var markerText = ""
    
    while index < context.tokens.count {
      let token = context.tokens[index]
      if token.element == .punctuation && token.text.first == char {
        charCount += token.text.count
        markerText += token.text
      } else if token.element == .whitespaces {
        // Whitespace is allowed between thematic break characters
        markerText += token.text
      } else if token.element == .newline || token.element == .eof {
        break
      } else {
        // Any other character means this is not a thematic break
        return false
      }
      index += 1
    }
    
    // Need at least 3 of the same character
    guard charCount >= 3 else { return false }
    
    // Create thematic break node
    let thematicBreak = ThematicBreakNode(marker: markerText.trimmingCharacters(in: .whitespaces))
    context.current.append(thematicBreak)
    
    // Thematic breaks are leaf elements and don't change context.current
    
    context.consuming = context.tokens.count
    return true
  }
}
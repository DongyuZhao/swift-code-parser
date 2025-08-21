import CodeParserCore
import Foundation

/// Handles setext heading creation following CommonMark spec
/// Setext headings are text followed by a line of = (level 1) or - (level 2) characters
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard !context.tokens.isEmpty else { return false }
    
    var index = 0
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < context.tokens.count && context.tokens[index].element == .whitespaces {
      leadingSpaces += context.tokens[index].text.count
      if leadingSpaces > 3 {
        return false // Too much indentation
      }
      index += 1
    }
    
    guard index < context.tokens.count else { return false }
    
    // Check for setext heading underline (= or -)
    let firstToken = context.tokens[index]
    guard firstToken.element == .punctuation else { return false }
    
    let char = firstToken.text.first!
    guard char == "=" || char == "-" else { return false }
    
    let level = char == "=" ? 1 : 2
    
    // Verify this is a valid underline (only = or - characters and whitespace)
    var hasUnderlineChar = false
    while index < context.tokens.count {
      let token = context.tokens[index]
      if token.element == .punctuation && token.text.first == char {
        hasUnderlineChar = true
      } else if token.element == .whitespaces {
        // Whitespace is allowed
      } else if token.element == .newline || token.element == .eof {
        break
      } else {
        // Other characters mean this is not a setext underline
        return false
      }
      index += 1
    }
    
    guard hasUnderlineChar else { return false }
    
    // Check if the previous line can be converted to a setext heading
    // Look for the last paragraph node that could be converted
    guard let paragraph = findLastConvertibleParagraph(in: context.current) else {
      return false
    }
    
    // Convert the paragraph to a heading
    let heading = HeaderNode(level: level)
    
    // Move the paragraph's content to the heading
    for child in paragraph.children {
      child.remove()
      heading.append(child)
    }
    
    // Replace the paragraph with the heading
    if let parent = paragraph.parent as? MarkdownNodeBase {
      let paragraphIndex = parent.children.firstIndex { $0 === paragraph } ?? 0
      paragraph.remove()
      parent.insert(heading, at: paragraphIndex)
    }
    
    // Don't change context.current - setext headings are leaf elements
    
    context.consuming = context.tokens.count
    return true
  }
  
  private func findLastConvertibleParagraph(in node: CodeNode<MarkdownNodeElement>) -> ParagraphNode? {
    // Look for the last child that is a paragraph
    for child in node.children.reversed() {
      if let paragraph = child as? ParagraphNode {
        // Check if this paragraph can be converted to a setext heading
        // It must contain only inline content (no blank lines)
        return paragraph
      }
      // If we encounter any other block element, stop searching
      if child is MarkdownNodeBase {
        break
      }
    }
    return nil
  }
}
import CodeParserCore
import Foundation

/// Handles paragraph creation following CommonMark spec
/// Paragraphs are sequences of non-blank lines that cannot be interpreted as other block constructs
public class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  
  public init() {}
  
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard !context.tokens.isEmpty else { return false }
    
    // Check if this line should close an existing paragraph
    if let currentParagraph = context.current as? ParagraphNode {
      // A blank line would have been handled by MarkdownBlockBuilder
      // Check for other block constructs that would close a paragraph
      if isBlockConstructStart(context.tokens) {
        // This line starts a new block construct, so close current paragraph
        if let parent = currentParagraph.parent {
          context.current = parent
        }
        return false // Let other builders handle this line
      }
      
      // Continue the paragraph - add this line's tokens to existing content
      addLineToParagraph(currentParagraph, tokens: context.tokens)
      context.consuming = context.tokens.count
      return true
    }
    
    // No current paragraph, check if this line can start a paragraph
    if canStartParagraph(context.tokens) {
      let paragraph = ParagraphNode(range: context.tokens.first!.range.lowerBound..<context.tokens.last!.range.upperBound)
      context.current.append(paragraph)
      context.current = paragraph
      
      // Create ContentNode with all non-newline tokens
      let contentTokens = context.tokens.filter { $0.element != .newline && $0.element != .eof }
      if !contentTokens.isEmpty {
        let contentNode = ContentNode(tokens: contentTokens)
        paragraph.append(contentNode)
      }
      
      context.consuming = context.tokens.count
      return true
    }
    
    return false
  }
  
  private func canStartParagraph(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    // Skip whitespace to find the first significant token
    let nonWhitespaceTokens = tokens.filter { 
      $0.element != .whitespaces && $0.element != .newline && $0.element != .eof 
    }
    
    // A paragraph can start if there are non-whitespace tokens
    // and the line doesn't start with block construct markers
    return !nonWhitespaceTokens.isEmpty && !isBlockConstructStart(tokens)
  }
  
  private func isBlockConstructStart(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var index = 0
    
    // Skip leading whitespace
    while index < tokens.count && tokens[index].element == .whitespaces {
      index += 1
    }
    
    guard index < tokens.count else { return false }
    let firstToken = tokens[index]
    
    // Check for various block construct markers
    switch firstToken.element {
    case .punctuation:
      let char = firstToken.text.first!
      switch char {
      case "#":
        // ATX heading
        return true
      case ">":
        // Block quote
        return true
      case "-", "*", "+":
        // Could be thematic break or list item
        return isThematicBreak(tokens, startIndex: index) || isListItem(tokens, startIndex: index)
      case "`", "~":
        // Fenced code block
        return isFencedCodeBlock(tokens, startIndex: index)
      default:
        break
      }
    case .characters:
      // Check for setext heading underline or numbered list
      if isSetextHeadingUnderline(tokens, startIndex: index) || isOrderedListMarker(tokens, startIndex: index) {
        return true
      }
    default:
      break
    }
    
    // Check for indented code block (4+ spaces)
    let leadingSpaces = countLeadingSpaces(tokens)
    return leadingSpaces >= 4
  }
  
  private func isThematicBreak(_ tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> Bool {
    guard startIndex < tokens.count else { return false }
    let char = tokens[startIndex].text.first!
    guard char == "-" || char == "*" || char == "_" else { return false }
    
    var count = 0
    var index = startIndex
    
    while index < tokens.count {
      let token = tokens[index]
      if token.element == .punctuation && token.text.first == char {
        count += token.text.count
      } else if token.element == .whitespaces {
        // Whitespace is allowed in thematic breaks
      } else if token.element == .newline || token.element == .eof {
        break
      } else {
        // Other characters mean this is not a thematic break
        return false
      }
      index += 1
    }
    
    return count >= 3
  }
  
  private func isListItem(_ tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> Bool {
    guard startIndex < tokens.count else { return false }
    let token = tokens[startIndex]
    
    // Check for unordered list marker
    if token.element == .punctuation && (token.text == "-" || token.text == "*" || token.text == "+") {
      // Must be followed by whitespace or end of line
      let nextIndex = startIndex + 1
      if nextIndex >= tokens.count {
        return true // End of line
      }
      let nextToken = tokens[nextIndex]
      return nextToken.element == .whitespaces || nextToken.element == .newline
    }
    
    return false
  }
  
  private func isFencedCodeBlock(_ tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> Bool {
    guard startIndex < tokens.count else { return false }
    let token = tokens[startIndex]
    guard token.element == .punctuation else { return false }
    
    let char = token.text.first!
    guard char == "`" || char == "~" else { return false }
    
    // Count consecutive fence characters
    var count = token.text.count
    var index = startIndex + 1
    
    while index < tokens.count && tokens[index].element == .punctuation && tokens[index].text.first == char {
      count += tokens[index].text.count
      index += 1
    }
    
    return count >= 3
  }
  
  private func isSetextHeadingUnderline(_ tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> Bool {
    guard startIndex < tokens.count else { return false }
    let token = tokens[startIndex]
    
    // Check for setext heading underline (= or -)
    if token.element == .punctuation {
      let char = token.text.first!
      if char == "=" || char == "-" {
        // Must be a line of only = or - characters (and whitespace)
        return isUniformLine(tokens, char: char, startIndex: startIndex)
      }
    }
    
    return false
  }
  
  private func isOrderedListMarker(_ tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> Bool {
    guard startIndex < tokens.count else { return false }
    
    var index = startIndex
    // Look for digits
    while index < tokens.count && tokens[index].element == .characters && tokens[index].text.allSatisfy({ $0.isNumber }) {
      index += 1
    }
    
    // Must have at least one digit
    if index == startIndex { return false }
    
    // Must be followed by . or )
    if index < tokens.count && tokens[index].element == .punctuation && (tokens[index].text == "." || tokens[index].text == ")") {
      index += 1
      // Must be followed by whitespace or end of line
      if index >= tokens.count || tokens[index].element == .whitespaces || tokens[index].element == .newline {
        return true
      }
    }
    
    return false
  }
  
  private func isUniformLine(_ tokens: [any CodeToken<MarkdownTokenElement>], char: Character, startIndex: Int) -> Bool {
    var index = startIndex
    var hasChar = false
    
    while index < tokens.count {
      let token = tokens[index]
      if token.element == .punctuation && token.text.first == char {
        hasChar = true
      } else if token.element == .whitespaces {
        // Whitespace is allowed
      } else if token.element == .newline || token.element == .eof {
        break
      } else {
        // Other characters mean this is not uniform
        return false
      }
      index += 1
    }
    
    return hasChar
  }
  
  private func countLeadingSpaces(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Int {
    guard let firstToken = tokens.first, firstToken.element == .whitespaces else { return 0 }
    return firstToken.text.count
  }
  
  private func addLineToParagraph(_ paragraph: ParagraphNode, tokens: [any CodeToken<MarkdownTokenElement>]) {
    // Find existing ContentNode or create new one
    let contentTokens = tokens.filter { $0.element != .newline && $0.element != .eof }
    
    if let existingContent = paragraph.children.first as? ContentNode {
      // Add a newline token to represent the line break, then add new content
      let newlineToken = MarkdownToken(element: .newline, text: "\n", range: tokens.first?.range ?? existingContent.tokens.last?.range ?? "".startIndex..<"".endIndex)
      existingContent.tokens.append(newlineToken)
      existingContent.tokens.append(contentsOf: contentTokens)
    } else {
      // Create new ContentNode
      let contentNode = ContentNode(tokens: contentTokens)
      paragraph.append(contentNode)
    }
  }
}
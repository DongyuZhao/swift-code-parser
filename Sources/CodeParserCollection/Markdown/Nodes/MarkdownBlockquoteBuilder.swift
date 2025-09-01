import CodeParserCore
import Foundation

/// Markdown-compliant blockquote builder
/// Handles blockquote blocks which are container blocks that can contain other blocks
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#block-quotes
public class MarkdownBlockquoteBuilder: MarkdownBlockBuilderProtocol {
  
  public var priority: Int { return 10 }
  public var blockType: MarkdownNodeElement { return .blockquote }
  
  public init() {}
  
  public func canContinue(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    guard block.element == .blockquote else { return false }
    
    // Blockquotes continue if the line starts with > (after up to 3 spaces)
    // or if it's a lazy continuation (non-empty line without >)
    return hasBlockquoteMarker(line) || isLazyContinuation(line, state: state)
  }
  
  public func canStart(
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    return hasBlockquoteMarker(line)
  }
  
  public func createBlock(
    from line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    let blockquote = BlockquoteNode()
    return blockquote
  }
  
  public func processLine(
    for block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard block.element == .blockquote else { return false }
    
    if hasBlockquoteMarker(line) {
      // Strip the blockquote marker and continue with the rest of the line
      let strippedLine = stripBlockquoteMarker(from: line)
      
      // Process the stripped line recursively with nested parsing
      // This is where the CommonMark algorithm recurses for container blocks
      processNestedLine(strippedLine, in: block, context: &context, state: state)
      
      // Mark the entire line as consumed
      state.position = line.count
      return true
    } else if isLazyContinuation(line, state: state) {
      // Lazy continuation - process the line as-is within the blockquote
      processNestedLine(line, in: block, context: &context, state: state)
      
      // Mark the entire line as consumed
      state.position = line.count
      return true
    }
    
    return false
  }
  
  public func shouldClose(
    block: MarkdownNodeBase, 
    line: [any CodeToken<MarkdownTokenElement>], 
    state: MarkdownConstructState
  ) -> Bool {
    // Blockquotes close when they can't continue
    return !canContinue(block: block, line: line, state: state)
  }
  
  // MARK: - Private Helper Methods
  
  /// Check if a line has a blockquote marker (> after up to 3 spaces)
  private func hasBlockquoteMarker(_ line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var index = 0
    var leadingSpaces = 0
    
    // Skip leading whitespace (up to 3 spaces)
    while index < line.count && line[index].element == .whitespaces {
      let spaceCount = line[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Check for > marker
    return index < line.count && 
           line[index].element == .punctuation && 
           line[index].text == ">"
  }
  
  /// Strip the blockquote marker (>) and optional following space from a line
  private func stripBlockquoteMarker(from line: [any CodeToken<MarkdownTokenElement>]) -> [any CodeToken<MarkdownTokenElement>] {
    var result: [any CodeToken<MarkdownTokenElement>] = []
    var index = 0
    
    // Skip leading whitespace
    while index < line.count && line[index].element == .whitespaces {
      index += 1
    }
    
    // Skip the > marker
    if index < line.count && line[index].element == .punctuation && line[index].text == ">" {
      index += 1
      
      // Skip one optional space after >
      if index < line.count && 
         line[index].element == .whitespaces && 
         line[index].text == " " {
        index += 1
      }
    }
    
    // Return the rest of the line
    while index < line.count {
      result.append(line[index])
      index += 1
    }
    
    return result
  }
  
  /// Check if this could be a lazy continuation of a blockquote
  /// Lazy continuation means a non-empty line without > that continues existing content
  private func isLazyContinuation(_ line: [any CodeToken<MarkdownTokenElement>], state: MarkdownConstructState) -> Bool {
    // For now, simplified: allow lazy continuation for non-empty lines
    // In a complete implementation, this would check if we're in paragraph context within the blockquote
    return !isBlankLine(line) && !hasBlockStartMarker(line)
  }
  
  /// Check if a line is blank
  private func isBlankLine(_ line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    for token in line {
      switch token.element {
      case .whitespaces, .newline:
        continue
      default:
        return false
      }
    }
    return true
  }
  
  /// Check if a line starts with a marker that would start a new block
  private func hasBlockStartMarker(_ line: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    // This is a simplified check - in practice, this would check for all block start patterns
    var index = 0
    
    // Skip leading whitespace
    while index < line.count && line[index].element == .whitespaces {
      index += 1
    }
    
    guard index < line.count else { return false }
    
    let token = line[index]
    if token.element == .punctuation {
      // Check for various block start markers
      switch token.text {
      case ">", "#", "*", "-", "+", "_":
        return true
      default:
        return false
      }
    }
    
    return false
  }
  
  /// Process a nested line within the blockquote context
  /// This is where we would recursively call the main parser for the nested content
  private func processNestedLine(
    _ line: [any CodeToken<MarkdownTokenElement>],
    in blockquote: MarkdownNodeBase,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
    state: MarkdownConstructState
  ) {
    // Set the current context to the blockquote for nested processing
    let originalCurrent = context.current
    context.current = blockquote as CodeNode<MarkdownNodeElement>
    
    // In a complete implementation, this would create a new parser instance
    // or recursively call the main parsing logic for the nested line
    // For now, simplified: just delegate to paragraph processing if line has content
    if !isBlankLine(line) {
      // Check if we need to create a new paragraph or continue existing one
      if blockquote.children.isEmpty || blockquote.children.last?.element != .paragraph {
        let dummyString = ""
        let range = dummyString.startIndex..<dummyString.endIndex
        let paragraph = ParagraphNode(range: range)
        blockquote.append(paragraph)
        context.current = paragraph
      } else {
        context.current = blockquote.children.last!
      }
      
      // Add content to paragraph (simplified)
      // In practice, this would use the paragraph builder or inline processing
    }
    
    // Restore original context
    context.current = originalCurrent
  }
}
import CodeParserCore
import Foundation

/// Processes emphasis (*text*) and strong emphasis (**text**)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis
public class MarkdownEmphasisProcessor: MarkdownContentProcessor {
  public let delimiters: Set<Character> = ["*", "_"]

  public init() {}

  public func process(
    _ token: any CodeToken<MarkdownTokenElement>,
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> Bool {
    guard token.element == .punctuation,
          let char = token.text.first,
          delimiters.contains(char) else {
      return false
    }

    // Aggregate consecutive delimiter tokens into a run
    let runInfo = buildDelimiterRun(
      startingAt: index,
      with: char,
      in: tokens,
      context: &context
    )
    
    // Create text node for the delimiter run
    let delimiterText = String(repeating: String(char), count: runInfo.length)
    let textNode = TextNode(content: delimiterText)
    context.add(textNode)
    
    // Create and push delimiter run to stack
    let delimiterType: MarkdownDelimiter = (char == "*") ? .asterisk : .underscore
    let delimiterRun = MarkdownDelimiterRun(
      type: delimiterType,
      length: runInfo.length,
      openable: runInfo.canOpen,
      closable: runInfo.canClose,
      index: context.inlined.count - 1
    )
    
    context.delimiters.push(delimiterRun, textNode: textNode)
    
    // Advance past the processed tokens
    context.advance(by: runInfo.length - 1)
    
    return true
  }

  public func finalize(context: inout MarkdownContentContext) {
    processEmphasisDelimiters(context: &context)
  }
  
  private func buildDelimiterRun(
    startingAt index: Int,
    with char: Character,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> (length: Int, canOpen: Bool, canClose: Bool) {
    
    var length = 0
    var currentIndex = index
    
    // Count consecutive delimiter characters
    while currentIndex < tokens.count,
          let token = tokens[currentIndex] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == String(char) {
      length += 1
      currentIndex += 1
    }
    
    // Determine if this run can open or close emphasis based on flanking rules
    let canOpen = isLeftFlanking(
      delimiterIndex: index,
      runLength: length,
      in: tokens
    )
    
    let canClose = isRightFlanking(
      delimiterIndex: index,
      runLength: length,
      in: tokens
    )
    
    return (length: length, canOpen: canOpen, canClose: canClose)
  }
  
  private func isLeftFlanking(
    delimiterIndex: Int,
    runLength: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> Bool {
    let afterIndex = delimiterIndex + runLength
    
    // A delimiter run is left-flanking if:
    // 1. It is not followed by Unicode whitespace
    // 2. And either:
    //    a. It is not followed by a punctuation character
    //    b. Or it is followed by a punctuation character and preceded by whitespace or punctuation
    
    // Check what follows
    guard afterIndex < tokens.count else {
      // End of input - not left-flanking
      return false
    }
    
    let afterToken = tokens[afterIndex]
    
    // Rule 1: Not followed by whitespace
    if afterToken.element == .whitespaces {
      return false
    }
    
    // Rule 2a: Not followed by punctuation - can open
    if afterToken.element != .punctuation {
      return true
    }
    
    // Rule 2b: Followed by punctuation, check what precedes
    let beforeIndex = delimiterIndex - 1
    if beforeIndex < 0 {
      // Start of input - can open
      return true
    }
    
    let beforeToken = tokens[beforeIndex]
    return beforeToken.element == .whitespaces || beforeToken.element == .punctuation
  }
  
  private func isRightFlanking(
    delimiterIndex: Int,
    runLength: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> Bool {
    let beforeIndex = delimiterIndex - 1
    
    // A delimiter run is right-flanking if:
    // 1. It is not preceded by Unicode whitespace
    // 2. And either:
    //    a. It is not preceded by a punctuation character  
    //    b. Or it is preceded by a punctuation character and followed by whitespace or punctuation
    
    // Check what precedes
    guard beforeIndex >= 0 else {
      // Start of input - not right-flanking
      return false
    }
    
    let beforeToken = tokens[beforeIndex]
    
    // Rule 1: Not preceded by whitespace
    if beforeToken.element == .whitespaces {
      return false
    }
    
    // Rule 2a: Not preceded by punctuation - can close
    if beforeToken.element != .punctuation {
      return true
    }
    
    // Rule 2b: Preceded by punctuation, check what follows
    let afterIndex = delimiterIndex + runLength
    if afterIndex >= tokens.count {
      // End of input - can close
      return true
    }
    
    let afterToken = tokens[afterIndex]
    return afterToken.element == .whitespaces || afterToken.element == .punctuation
  }
  
  private func processEmphasisDelimiters(context: inout MarkdownContentContext) {
    // Process emphasis using the algorithm from CommonMark spec
    var currentDelimiterNode = context.delimiters.forward(from: nil)
    
    while let closerNode = currentDelimiterNode.next() {
      guard closerNode.run.closable,
            (closerNode.run.delimiter == .asterisk || closerNode.run.delimiter == .underscore) else {
        continue
      }
      
      // Look for opener
      if let openerNode = context.delimiters.opener(for: closerNode.run.delimiter, before: closerNode) {
        
        // Determine emphasis type based on delimiter run lengths
        let useLength = min(openerNode.run.length, closerNode.run.length)
        let isStrong = useLength >= 2
        
        // Create emphasis or strong node
        let emphasisNode: MarkdownNodeBase = isStrong ? StrongNode(content: "") : EmphasisNode(content: "")
        
        // Move content between opener and closer into emphasis node
        moveContentBetween(
          opener: openerNode,
          closer: closerNode,
          into: emphasisNode,
          useLength: useLength,
          context: &context
        )
        
        // Clean up delimiter stack
        context.delimiters.clear(after: openerNode)
        break
      }
    }
  }
  
  private func moveContentBetween(
    opener: MarkdownDelimiterStackNode,
    closer: MarkdownDelimiterStackNode,
    into emphasisNode: MarkdownNodeBase,
    useLength: Int,
    context: inout MarkdownContentContext
  ) {
    // This is a simplified implementation
    // In a complete implementation, we'd need to:
    // 1. Find the content between opener and closer in context.inlined
    // 2. Move it into the emphasis node
    // 3. Update the delimiter text nodes to reflect the consumed delimiters
    // 4. Insert the emphasis node at the appropriate location
    
    // For now, just mark delimiters as inactive to prevent further processing
    opener.run.isActive = false
    closer.run.isActive = false
  }
}
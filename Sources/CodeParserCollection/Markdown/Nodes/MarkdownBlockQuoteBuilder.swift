import CodeParserCore
import Foundation

/// Handles block quote creation following CommonMark spec
/// Block quotes start with > and can be continued on subsequent lines
public class MarkdownBlockQuoteBuilder: CodeNodeBuilder {
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
        // Check if we're continuing an existing block quote without >
        return handleBlockQuoteContinuation(&context, originalIndex: 0)
      }
      index += 1
    }
    
    // Check for block quote marker >
    var hasBlockQuoteMarker = false
    if index < context.tokens.count {
      let token = context.tokens[index]
      if token.element == .punctuation && token.text == ">" {
        hasBlockQuoteMarker = true
        index += 1
        
        // Optional space after >
        if index < context.tokens.count && context.tokens[index].element == .whitespaces {
          index += 1
        }
      }
    }
    
    if hasBlockQuoteMarker {
      // This line starts with > so it's definitely a block quote line
      let contentTokens = Array(context.tokens[index...]).filter { $0.element != .newline && $0.element != .eof }
      
      if let existingBlockQuote = context.current as? BlockquoteNode {
        // Continue existing block quote
        addLineToBlockQuote(existingBlockQuote, tokens: contentTokens)
      } else {
        // Create new block quote
        let blockQuote = BlockquoteNode()
        context.current.append(blockQuote)
        context.current = blockQuote
        
        if !contentTokens.isEmpty {
          let contentNode = ContentNode(tokens: contentTokens)
          blockQuote.append(contentNode)
        }
      }
      
      context.consuming = context.tokens.count
      return true
    }
    
    // No > marker, check if we should continue an existing block quote
    return handleBlockQuoteContinuation(&context, originalIndex: 0)
  }
  
  private func handleBlockQuoteContinuation(_ context: inout CodeConstructContext<Node, Token>, originalIndex: Int) -> Bool {
    // Check if we're currently in a block quote
    guard let existingBlockQuote = context.current as? BlockquoteNode else {
      return false
    }
    
    // This line continues the block quote (lazy continuation)
    let contentTokens = context.tokens.filter { $0.element != .newline && $0.element != .eof }
    addLineToBlockQuote(existingBlockQuote, tokens: contentTokens)
    
    context.consuming = context.tokens.count
    return true
  }
  
  private func addLineToBlockQuote(_ blockQuote: BlockquoteNode, tokens: [any CodeToken<MarkdownTokenElement>]) {
    if let existingContent = blockQuote.children.first as? ContentNode {
      // Add a newline token to represent the line break, then add new content
      let newlineToken = MarkdownToken(element: .newline, text: "\n", range: tokens.first?.range ?? existingContent.tokens.last?.range ?? "".startIndex..<"".endIndex)
      existingContent.tokens.append(newlineToken)
      existingContent.tokens.append(contentsOf: tokens)
    } else if !tokens.isEmpty {
      // Create new ContentNode
      let contentNode = ContentNode(tokens: tokens)
      blockQuote.append(contentNode)
    }
  }
}
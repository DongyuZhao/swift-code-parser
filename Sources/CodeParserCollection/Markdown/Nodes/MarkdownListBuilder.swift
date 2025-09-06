import CodeParserCore
import Foundation

/// Builder for list containers (unordered_list, ordered_list)
/// Handles proper list structure creation and context manipulation
public class MarkdownListBuilder: MarkdownBlockBuilderProtocol {
  
  public let priority: Int = 55 // Higher priority than list items to create containers first
  
  public init() {}
  
  public func canHandle(block: any MarkdownBlockNode) -> Bool {
    return block.blockType == "unordered_list" || block.blockType == "ordered_list"
  }
  
  public func isContainerBuilder() -> Bool {
    return true
  }
  
  public func canStart(line: MarkdownLine) -> Bool {
    // This builder creates list containers when list items are detected
    // But it doesn't start directly from lines - it's triggered by list item detection
    return isListItemLine(line)
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    // List containers can continue by adding more list items
    guard block as? ListNode != nil else { return false }
    
    // Check if this line is a compatible list item
    if isListItemLine(line) {
      let isOrdered = block.blockType == "ordered_list"
      return isCompatibleListItem(line: line, isOrderedList: isOrdered)
    }
    
    return false
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard isListItemLine(line) else { return nil }
    
    // Determine if this is ordered or unordered
    if isOrderedListItem(line) {
      return OrderedListNode(level: 1)
    } else {
      // Get marker for unordered list
      let marker = extractUnorderedMarker(from: line) ?? "-"
      return UnorderedListNode(level: 1, marker: marker)
    }
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    // List containers don't process lines directly - their child list items do
    // This method should create a list item and add it to the container
    guard let listContainer = block as? ListNode else { return false }
    
    // Create a list item for this line
    if let listItem = createListItem(from: line) {
      // Add the list item to the container
      let containerNode = listContainer as MarkdownNodeBase
      containerNode.append(listItem as! MarkdownNodeBase)
      
      // Yield back tokens for the list item to process its content
      let listItemBuilder = MarkdownListItemBuilder()
      _ = listItemBuilder.processLine(block: listItem, line: line, state: &state)
      
      return true
    }
    
    return false
  }
  
  public func canInterrupt() -> Bool {
    return false
  }
  
  public func moveContextOnClose(block: any MarkdownBlockNode, context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) {
    // When lists are closed, move context to parent (usually document)
    if let parent = context.current.parent {
      context.current = parent
    }
  }
  
  // MARK: - Helper Methods
  
  private func isListItemLine(_ line: MarkdownLine) -> Bool {
    let listItemBuilder = MarkdownListItemBuilder()
    return listItemBuilder.canStart(line: line)
  }
  
  private func isOrderedListItem(_ line: MarkdownLine) -> Bool {
    // Look for digit(s) followed by . or )
    var tokenIndex = 0
    
    // Skip leading whitespace
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { return false }
    
    let token = line.tokens[tokenIndex]
    if token.element == .characters && token.text.count <= 9 && token.text.allSatisfy(\.isNumber) {
      let nextIndex = tokenIndex + 1
      if nextIndex < line.tokens.count {
        let nextToken = line.tokens[nextIndex]
        return nextToken.element == .punctuation && (nextToken.text == "." || nextToken.text == ")")
      }
    }
    
    return false
  }
  
  private func extractUnorderedMarker(from line: MarkdownLine) -> String? {
    var tokenIndex = 0
    
    // Skip leading whitespace
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { return nil }
    
    let token = line.tokens[tokenIndex]
    if token.element == .punctuation && (token.text == "-" || token.text == "*" || token.text == "+") {
      return token.text
    }
    
    return nil
  }
  
  private func isCompatibleListItem(line: MarkdownLine, isOrderedList: Bool) -> Bool {
    if isOrderedList {
      return isOrderedListItem(line)
    } else {
      return !isOrderedListItem(line) && isListItemLine(line)
    }
  }
  
  private func createListItem(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    let listItemBuilder = MarkdownListItemBuilder()
    return listItemBuilder.createBlock(from: line)
  }
}
import CodeParserCore
import Foundation

/// Handles list items for both ordered and unordered lists
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#list-items
public class MarkdownListItemBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    // Don't process list items when inside a fenced code block
    if state.openFence != nil {
      return false
    }

    // In phased pipeline, builders receive the suffix tokens; always start at local 0
    let startIndex = 0
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check for list item markers
    if let markerInfo = detectListMarker(tokens: context.tokens, startIndex: startIndex) {
      // Handle paragraph interruption rules
      if context.current.element == .paragraph {
        let isInsideListItem = context.current.parent is ListItemNode
        
        switch markerInfo.type {
        case .unordered:
          // Unordered bullets may interrupt a paragraph
          if let parent = context.current.parent {
            context.current = parent
          }
        case .ordered(let number, _):
          // Only allow interruption when starting from 1, unless we're inside a list item
          if !isInsideListItem && number != 1 { 
            return false 
          }
          if let parent = context.current.parent {
            context.current = parent
          }
        }
      }

      // Determine proper nesting based on indentation and current context
      let targetContext = determineListContext(markerInfo: markerInfo, context: &context, state: state)
      context.current = targetContext

      return createListItem(markerInfo: markerInfo, context: &context, state: state)
    }

    return false
  }

  private func detectListMarker(
    tokens: [any CodeToken<MarkdownTokenElement>],
    startIndex: Int
  ) -> ListMarkerInfo? {
    var index = startIndex
  var indentation = 0

    // Count leading indentation (up to 3 spaces allowed)
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      let spaceCount = tokens[index].text.count
      if indentation + spaceCount > 3 {
        return nil // Too much indentation for list item
      }
      indentation += spaceCount
      index += 1
    }

    guard index < tokens.count else { return nil }

    let markerToken = tokens[index]
    // Helper to build result with computed contentIndent
    func makeInfo(type: ListMarkerType, markerEndIndex: Int, afterHasSpaceOrEOL: Bool) -> ListMarkerInfo? {
      // Marker width: unordered 1; ordered = digits + 1 delimiter
      let markerWidth: Int
      switch type {
      case .unordered:
        markerWidth = 1
      case .ordered(let number, let delimiter):
        // number of digits
        markerWidth = String(number).count + delimiter.count
      }

      // Require at least one space or EOL per spec
      guard afterHasSpaceOrEOL else { return nil }
      let contentIndent = indentation + markerWidth + 1
      return ListMarkerInfo(
        type: type,
        markerEndIndex: markerEndIndex,
        indentation: indentation,
        contentIndent: contentIndent
      )
    }

    // Check for unordered list markers
  if markerToken.element == .punctuation {
      switch markerToken.text {
      case "-", "*", "+":
        // Must be followed by space or end of line
        if index + 1 < tokens.count {
          let nextToken = tokens[index + 1]
      let ok = (nextToken.element == .whitespaces || nextToken.element == .newline)
      return makeInfo(type: .unordered(marker: markerToken.text), markerEndIndex: index + 1, afterHasSpaceOrEOL: ok)
        } else {
          // End of line after marker
      return makeInfo(type: .unordered(marker: markerToken.text), markerEndIndex: index + 1, afterHasSpaceOrEOL: true)
        }
      default:
        break
      }
    }

    // Check for ordered list markers (number followed by . or ))
    if markerToken.element == .characters {
      // Extract number
      if let number = Int(markerToken.text), index + 1 < tokens.count {
        // Enforce at most 9 digits
        if markerToken.text.count > 9 { return nil }
        let delimiterToken = tokens[index + 1]
        if delimiterToken.element == .punctuation {
          switch delimiterToken.text {
          case ".", ")":
            // Must be followed by space or end of line
            if index + 2 < tokens.count {
              let nextToken = tokens[index + 2]
              let ok = (nextToken.element == .whitespaces || nextToken.element == .newline)
              return makeInfo(type: .ordered(number: number, delimiter: delimiterToken.text), markerEndIndex: index + 2, afterHasSpaceOrEOL: ok)
            } else {
              // End of line after delimiter
              return makeInfo(type: .ordered(number: number, delimiter: delimiterToken.text), markerEndIndex: index + 2, afterHasSpaceOrEOL: true)
            }
          default:
            break
          }
        }
      }
    }

    return nil
  }

  /// Determines the proper context for creating a list item based on indentation and current AST position
  private func determineListContext(
    markerInfo: ListMarkerInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> CodeNode<MarkdownNodeElement> {
    // Start from current context
    var currentNode = context.current
    
    // First check if current context itself can accommodate nesting
    if let listItem = currentNode as? ListItemNode {
      let contentIndent = listItem.contentIndent
      
      if markerInfo.indentation >= contentIndent {
        // This marker is indented enough to be nested under this list item
        return listItem
      }
      // If not nested, continue to check parent contexts
    }
    
    // Walk up the ancestry to find list-related contexts
    while let parentNode = currentNode.parent {
      if let listItem = parentNode as? ListItemNode {
        // Found a parent list item - check if current marker should be nested under it
        let parentContentIndent = listItem.contentIndent
        
        if markerInfo.indentation >= parentContentIndent {
          // This marker is indented enough to be nested under this list item
          return listItem
        } else {
          // Not indented enough for this level - continue looking for higher levels
          if let parentList = listItem.parent {
            currentNode = parentList
            continue
          }
        }
      } else if let list = parentNode as? ListNode {
        // Found a parent list - check if this should be a sibling item
        if markerInfo.indentation == 0 || // At document level
           !isCompatibleForSiblingContinuation(markerInfo.type, with: list) {
          // Either at document level or incompatible marker - look for higher level
          currentNode = parentNode
          continue
        } else {
          // Compatible marker at appropriate level - add as sibling
          return list
        }
      }
      currentNode = parentNode
    }
    
    // Fallback: return document or top-level context
    return findDocumentOrTopLevelContext(from: context.current)
  }
  
  /// Check if the new marker type is compatible for continuing as a sibling in the existing list
  private func isCompatibleForSiblingContinuation(_ newMarkerType: ListMarkerType, with existingList: ListNode) -> Bool {
    switch (existingList, newMarkerType) {
    case (let ul as UnorderedListNode, .unordered(let marker)):
      return ul.marker == marker
    case (let ol as OrderedListNode, .ordered(_, let delimiter)):
      return ol.delimiter == delimiter
    default:
      return false
    }
  }
  
  /// Find the document or top-level context for creating new lists
  private func findDocumentOrTopLevelContext(from current: CodeNode<MarkdownNodeElement>) -> CodeNode<MarkdownNodeElement> {
    var node = current
    
    // Walk up to find document or another suitable top-level container
    while let parent = node.parent {
      if parent.element == .document {
        return parent
      }
      // Also handle other potential top-level containers like blockquotes
      if parent.element == .blockquote {
        return parent
      }
      node = parent
    }
    
    // Fallback to current if we can't find a better context
    return current
  }

  private func createListItem(
    markerInfo: ListMarkerInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    // Create appropriate list container if needed
    let list = getOrCreateList(for: markerInfo.type, in: &context, state: state)

    // Create list item
    let markerText = markerInfo.type.markerText
    let listItem = ListItemNode(marker: markerText)
    listItem.markerIndent = markerInfo.indentation
    listItem.contentIndent = markerInfo.contentIndent
    list.append(listItem)

    // Update list stack for nesting tracking
    updateListStack(list: list, state: state)

    // Set current context to the list item for nested content
    context.current = listItem

    // Find content after marker (skip whitespace after marker)
    var contentStartIndex = markerInfo.markerEndIndex
    if contentStartIndex < context.tokens.count,
       context.tokens[contentStartIndex].element == .whitespaces {
      contentStartIndex += 1
    }

    // Update state to process remaining tokens as nested content in the list item
    state.position += contentStartIndex
    state.refreshed = true

    return true
  }

  private func updateListStack(list: ListNode, state: MarkdownConstructState) {
    // Maintain list stack for proper nesting tracking
    // Remove any lists that are no longer active (based on current position in AST)
    state.listStack = state.listStack.filter { stackList in
      // Keep lists that are ancestors of the current list
      var current: CodeNode<MarkdownNodeElement>? = list
      while let node = current {
        if node === stackList {
          return true
        }
        current = node.parent
      }
      return false
    }
    
    // Add current list to stack if not already present
    if !state.listStack.contains(where: { $0 === list }) {
      state.listStack.append(list)
    }
  }

  private func getOrCreateList(
    for markerType: ListMarkerType,
    in context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> ListNode {
    // Use the current context (which was determined by determineListContext)
    let containerContext = context.current
    
    // If the current context is already a compatible list, use it
    if let currentList = containerContext as? ListNode,
       currentList.isCompatible(with: markerType) {
      return currentList
    }

    // Check if the last child of the container is a compatible list
    if let lastChild = containerContext.children.last as? ListNode,
       lastChild.isCompatible(with: markerType) {
      return lastChild
    }

    // Determine the appropriate level for a new list based on nesting context
    let inferredLevel = inferListLevel(from: containerContext, state: state)

    // Create new list with inferred level
    let newList: ListNode
    switch markerType {
    case .unordered(let marker):
      newList = UnorderedListNode(level: inferredLevel, marker: marker)
    case .ordered(let number, let delimiter):
      newList = OrderedListNode(start: number, level: inferredLevel, delimiter: delimiter)
    }

    containerContext.append(newList)
    
    return newList
  }

  private func inferListLevel(from container: CodeNode<MarkdownNodeElement>, state: MarkdownConstructState) -> Int {
    // Use the list stack to determine proper nesting level
    if container is ListItemNode {
      // Creating sublist within a list item - level should be parent + 1
      return state.listStack.count + 1
    }
    
    // Look at existing lists to determine appropriate level
    if let lastList = container.children.last as? ListNode {
      // Same level as the last list in this container
      return lastList.level
    }
    
    // Default level based on container and stack depth
    if container.element == .document {
      return 1
    } else if let parentList = container as? ListNode {
      return parentList.level + 1
    } else {
      // Use stack depth as fallback
      return max(1, state.listStack.count)
    }
  }
}

// Helper types for list processing
private enum ListMarkerType {
  case unordered(marker: String)
  case ordered(number: Int, delimiter: String)

  var markerText: String {
    switch self {
    case .unordered(let marker):
      return marker
    case .ordered(let number, let delimiter):
      return "\(number)\(delimiter)"
    }
  }
}

private struct ListMarkerInfo {
  let type: ListMarkerType
  let markerEndIndex: Int
  let indentation: Int
  let contentIndent: Int
}

// Extension to check list compatibility
extension ListNode {
  fileprivate func isCompatible(with markerType: ListMarkerType) -> Bool {
    switch (self, markerType) {
    case (let ul as UnorderedListNode, .unordered(let marker)):
      return ul.marker == marker
    case (let ol as OrderedListNode, .ordered(_, let delimiter)):
      return ol.delimiter == delimiter
    default:
      return false
    }
  }
}
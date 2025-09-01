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
      // Respect paragraph-interruption rules:
      // - Unordered bullets may interrupt a paragraph
      // - Ordered lists may interrupt only when starting number is 1, BUT
      //   this rule doesn't apply to paragraphs inside list items (they can continue with any number)
      if context.current.element == .paragraph {
        // Check if this paragraph is inside a list item
        let isInsideListItem = context.current.parent is ListItemNode
        
        switch markerInfo.type {
        case .unordered:
          // Allowed: close the paragraph before starting the list
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

      // If we're currently inside a paragraph under a list item, determine whether
      // this marker should create a sibling item (same level) or a nested sublist.
      if context.current.element == .paragraph,
         let li = context.current.parent as? ListItemNode,
         let parentList = li.parent as? ListNode {
        if markerInfo.indentation >= 2 {
          // Nested sublist: keep current within the list item so a new sublist can be created
        } else {
          // Sibling at same level: move current to the parent list container
          context.current = parentList
        }
      }

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

  private func createListItem(
    markerInfo: ListMarkerInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    // Create appropriate list container if needed
  let list = getOrCreateList(for: markerInfo.type, in: &context)

    // Create list item
    let markerText = markerInfo.type.markerText
  let listItem = ListItemNode(marker: markerText)
  listItem.markerIndent = markerInfo.indentation
  // Minimal content indent = indentation + marker width + 1 space
  listItem.contentIndent = markerInfo.contentIndent
    list.append(listItem)

    // Set current context to the list item for nested content
    context.current = listItem

    // Find content after marker (skip whitespace after marker)
  var contentStartIndex = markerInfo.markerEndIndex
    if contentStartIndex < context.tokens.count,
       context.tokens[contentStartIndex].element == .whitespaces {
      contentStartIndex += 1
    }

    // Update state to process remaining tokens as nested content in the list item
    // Advance global position relative to local slice and re-run builders on same line
    state.position += contentStartIndex
    state.refreshed = true

    return true
  }

  private func getOrCreateList(
    for markerType: ListMarkerType,
    in context: inout CodeConstructContext<Node, Token>
  ) -> MarkdownNodeBase {
    // First, find the appropriate container context (usually document or parent list)
    var containerContext = findListContainer(from: context.current)
    
    // Check if the container context is already a compatible list
    if let currentList = containerContext as? ListNode,
       currentList.isCompatible(with: markerType) {
      return currentList
    }

    // Check if the last child of the container is a compatible list
    if let lastChild = containerContext.children.last as? ListNode,
       lastChild.isCompatible(with: markerType) {
      return lastChild
    }

    // Determine the appropriate level for a new list
    let inferredLevel = inferListLevel(from: containerContext, for: markerType)

    // Create new list with inferred level
    let newList: ListNode
    switch markerType {
    case .unordered(let marker):
      newList = UnorderedListNode(level: inferredLevel, marker: marker)
    case .ordered(let number, let delimiter):
      newList = OrderedListNode(start: number, level: inferredLevel, delimiter: delimiter)
    }

    containerContext.append(newList)
    
    // Update context to point to the container where we added the list
    context.current = containerContext
    
    return newList
  }
  
  private func findListContainer(from current: CodeNode<MarkdownNodeElement>) -> CodeNode<MarkdownNodeElement> {
    // Walk up the tree to find an appropriate container for lists
    var node = current
    
    // If we're in a list item, go to its parent list, then to that list's parent
    if node.element == .listItem, let parent = node.parent {
      node = parent // Now at the list level
      if let grandParent = node.parent {
        node = grandParent // Now at the list's container (usually document)
      }
    }
    // If we're already at a list, go to its parent container
    else if node.element == .orderedList || node.element == .unorderedList {
      if let parent = node.parent {
        node = parent
      }
    }
    // For other contexts like paragraph, go to parent
    else if node.element == .paragraph, let parent = node.parent {
      node = parent
    }
    
    return node
  }
  
  private func inferListLevel(from container: CodeNode<MarkdownNodeElement>, for markerType: ListMarkerType) -> Int {
    // Look at existing lists to determine appropriate level
    if let lastList = container.children.last as? ListNode {
      // Same level as the last list in this container
      return lastList.level
    }
    
    // Default level based on container
    if container.element == .document {
      return 1
    } else if let parentList = container as? ListNode {
      return parentList.level + 1
    } else {
      return 1
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
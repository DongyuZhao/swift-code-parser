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

    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check for list item markers
    if let markerInfo = detectListMarker(tokens: context.tokens, startIndex: startIndex) {
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
    
    // Check for unordered list markers
    if markerToken.element == .punctuation {
      switch markerToken.text {
      case "-", "*", "+":
        // Must be followed by space or end of line
        if index + 1 < tokens.count {
          let nextToken = tokens[index + 1]
          if nextToken.element == .whitespaces || nextToken.element == .newline {
            return ListMarkerInfo(
              type: .unordered(marker: markerToken.text),
              markerEndIndex: index + 1,
              indentation: indentation
            )
          }
        } else {
          // End of line after marker
          return ListMarkerInfo(
            type: .unordered(marker: markerToken.text),
            markerEndIndex: index + 1,
            indentation: indentation
          )
        }
      default:
        break
      }
    }
    
    // Check for ordered list markers (number followed by . or ))
    if markerToken.element == .characters {
      // Extract number
      if let number = Int(markerToken.text), index + 1 < tokens.count {
        let delimiterToken = tokens[index + 1]
        if delimiterToken.element == .punctuation {
          switch delimiterToken.text {
          case ".", ")":
            // Must be followed by space or end of line
            if index + 2 < tokens.count {
              let nextToken = tokens[index + 2]
              if nextToken.element == .whitespaces || nextToken.element == .newline {
                return ListMarkerInfo(
                  type: .ordered(number: number, delimiter: delimiterToken.text),
                  markerEndIndex: index + 2,
                  indentation: indentation
                )
              }
            } else {
              // End of line after delimiter
              return ListMarkerInfo(
                type: .ordered(number: number, delimiter: delimiterToken.text),
                markerEndIndex: index + 2,
                indentation: indentation
              )
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
    let list = getOrCreateList(for: markerInfo.type, in: context)
    
    // Create list item
    let markerText = markerInfo.type.markerText
    let listItem = ListItemNode(marker: markerText)
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
    state.position = contentStartIndex
    state.refreshed = true
    
    return true
  }
  
  private func getOrCreateList(
    for markerType: ListMarkerType,
    in context: CodeConstructContext<Node, Token>
  ) -> MarkdownNodeBase {
    // Check if the current context is already a compatible list
    if let currentList = context.current as? ListNode,
       currentList.isCompatible(with: markerType) {
      return currentList
    }
    
    // Check if the last child is a compatible list
    if let lastChild = context.current.children.last as? ListNode,
       lastChild.isCompatible(with: markerType) {
      return lastChild
    }
    
    // Create new list
    let newList: ListNode
    switch markerType {
    case .unordered:
      newList = UnorderedListNode()
    case .ordered(let number, _):
      newList = OrderedListNode(start: number)
    }
    
    context.current.append(newList)
    return newList
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
}

// Extension to check list compatibility
extension ListNode {
  fileprivate func isCompatible(with markerType: ListMarkerType) -> Bool {
    switch (self, markerType) {
    case (is UnorderedListNode, .unordered):
      return true
    case (is OrderedListNode, .ordered):
      return true
    default:
      return false
    }
  }
}
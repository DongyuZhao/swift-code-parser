import CodeParserCore
import Foundation

/// Unified list builder that handles both list item detection and list management
/// Replaces the dual MarkdownListBuilder + MarkdownListItemBuilder approach
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#lists
public class MarkdownUnifiedListBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    // Don't process lists when inside a fenced code block
    if state.openFence != nil {
      return false
    }

    // IMPORTANT: Check for new list item markers FIRST
    // This is critical because list markers should override continuation logic
    if let markerInfo = detectListMarker(tokens: context.tokens, startIndex: 0) {
      return handleNewListItem(markerInfo: markerInfo, context: &context, state: state)
    }

    // Second, check if we need to handle list continuation (existing list context)
    if let handledContinuation = handleListContinuation(context: &context, state: state) {
      return handledContinuation
    }

    return false
  }

  // MARK: - Enhanced List Continuation Logic with AST Traversal
  
  private func handleListContinuation(
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool? {
    // Use enhanced AST traversal to find the appropriate list context
    let listContext = findCurrentListContext(from: context.current, state: state)
    
    if let listContextInfo = listContext {
      return handleListContinuation(inContext: listContextInfo, tokens: context.tokens, state: state, constructContext: &context)
    }
    
    return nil // Indicates no continuation context found
  }
  
  /// Enhanced AST traversal to find the current list context with full indentation info
  private func findCurrentListContext(from current: CodeNode<MarkdownNodeElement>, state: MarkdownConstructState) -> ListContextInfo? {
    // First, try to use the enhanced context stack if available
    if let lastContext = state.listContextStack.last {
      // Verify the context is still valid by checking AST ancestry
      if isContextValidForCurrentPosition(lastContext, current: current) {
        return lastContext
      }
    }
    
    // Fallback to AST traversal to rebuild context
    return buildListContextFromAST(current: current)
  }
  
  /// Validate that a cached list context is still valid for the current AST position
  private func isContextValidForCurrentPosition(_ context: ListContextInfo, current: CodeNode<MarkdownNodeElement>) -> Bool {
    // Walk up from current to see if we're still in the context of this list
    var node: CodeNode<MarkdownNodeElement>? = current
    while let n = node {
      if n === context.list {
        return true
      }
      if let listItem = n as? ListItemNode, listItem === context.parentListItem {
        return true
      }
      node = n.parent
    }
    return false
  }
  
  /// Build list context information by traversing the AST
  private func buildListContextFromAST(current: CodeNode<MarkdownNodeElement>) -> ListContextInfo? {
    var node: CodeNode<MarkdownNodeElement>? = current
    var listLevels: [ListContextInfo] = []
    
    // Walk up the AST to find all list contexts
    while let n = node {
      if let list = n as? ListNode {
        let parentListItem = findParentListItem(for: list)
        let level = listLevels.count + 1
        let markerType = getListMarkerType(list)
        let contentIndent = calculateContentIndent(for: list, parentListItem: parentListItem, level: level)
        
        let contextInfo = ListContextInfo(
          list: list,
          parentListItem: parentListItem,
          contentIndent: contentIndent,
          level: level,
          markerType: markerType
        )
        listLevels.insert(contextInfo, at: 0) // Insert at beginning to maintain order
      }
      node = n.parent
    }
    
    // Return the deepest (most nested) list context
    return listLevels.last
  }
  
  /// Find the parent list item that contains a given list
  private func findParentListItem(for list: ListNode) -> ListItemNode? {
    return list.parent as? ListItemNode
  }
  
  /// Get the marker type string for a list
  private func getListMarkerType(_ list: ListNode) -> String {
    if let ul = list as? UnorderedListNode {
      return ul.marker
    } else if let ol = list as? OrderedListNode {
      return ol.delimiter
    }
    return ""
  }
  
  /// Calculate proper content indentation for a list context
  private func calculateContentIndent(for list: ListNode, parentListItem: ListItemNode?, level: Int) -> Int {
    if let parentItem = parentListItem {
      // For nested lists, base indentation on parent list item's content indent
      // This is the key fix: nested lists should use parent's content indent as base
      return parentItem.contentIndent
    } else {
      // For top-level lists, calculate based on the marker
      if let ul = list as? UnorderedListNode {
        return 2 // "- " = 2 characters minimum
      } else if let ol = list as? OrderedListNode {
        // Calculate based on start number length + delimiter + space
        let numberStr = String(ol.start)
        return numberStr.count + 1 + 1 // number + delimiter + space
      }
      return 2 // fallback
    }
  }
  
  /// Enhanced list item creation with proper content indent calculation
  private func createListItemWithProperIndent(
    markerInfo: ListMarkerInfo,
    list: ListNode,
    state: MarkdownConstructState
  ) -> ListItemNode {
    let markerText = markerInfo.type.markerText
    let listItem = ListItemNode(marker: markerText)
    listItem.markerIndent = markerInfo.indentation
    
    // Enhanced content indent calculation based on actual context
    let enhancedContentIndent = calculateEnhancedContentIndent(
      markerInfo: markerInfo,
      list: list,
      state: state
    )
    listItem.contentIndent = enhancedContentIndent
    
    return listItem
  }
  
  /// Calculate enhanced content indent based on full context
  private func calculateEnhancedContentIndent(
    markerInfo: ListMarkerInfo,
    list: ListNode,
    state: MarkdownConstructState
  ) -> Int {
    // Use the marker info's calculated content indent as base
    var contentIndent = markerInfo.contentIndent
    
    // For nested lists, ensure we account for the full nesting context
    if let parentListItem = findParentListItem(for: list) {
      // Ensure nested content indent is at least as much as parent's content indent
      contentIndent = max(contentIndent, parentListItem.contentIndent)
    }
    
    return contentIndent
  }

  
  /// Enhanced continuation logic using list context information
  private func handleListContinuation(
    inContext contextInfo: ListContextInfo,
    tokens: [any CodeToken<MarkdownTokenElement>],
    state: MarkdownConstructState,
    constructContext: inout CodeConstructContext<Node, Token>
  ) -> Bool {
    // Handle blank lines differently - they should not immediately force continuation
    guard !tokens.isEmpty else {
      // Blank line within list: allow proper blank line handling by other builders
      state.lastWasBlankLine = true
      return false
    }

    // If this line begins with a new list marker or blockquote marker, do not treat as continuation
    if startsWithListOrQuoteMarker(tokens) {
      return false
    }
    
    // If this line begins with other block-starting constructs, do not treat as continuation
    if startsWithBlockConstruct(tokens) {
      return false
    }

    // Calculate actual leading indentation
    let leadingIndent = calculateLeadingIndentation(tokens)
    
    // Enhanced indentation logic: check if this content should continue the current list context
    if shouldContinueInListContext(leadingIndent: leadingIndent, contextInfo: contextInfo, tokens: tokens) {
      // Find the appropriate list item to continue
      if let targetListItem = findTargetListItemForContinuation(contextInfo: contextInfo, leadingIndent: leadingIndent, constructContext: constructContext) {
        // Set context to the target list item for content continuation
        constructContext.current = targetListItem
        
        // Handle paragraph continuation vs creation based on blank line context
        handleParagraphContinuationInListItem(targetListItem, state: state, hasBlankLineBefore: state.lastWasBlankLine)
        
        // Return true to indicate we've set the correct context
        // Let the leafOnLine phase builders handle the actual content in this context
        return true
      }
    }

    return false
  }
  
  /// Check if line starts with block-starting constructs that should interrupt list continuation
  private func startsWithBlockConstruct(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var index = 0
    
    // Skip leading whitespace
    if index < tokens.count && tokens[index].element == .whitespaces {
      index += 1
    }
    
    guard index < tokens.count else { return false }
    
    let token = tokens[index]
    
    // ATX headings (# ## ### etc)
    if token.element == .punctuation && token.text.hasPrefix("#") {
      return true
    }
    
    // Thematic breaks (--- *** ___)
    if token.element == .punctuation && (token.text == "-" || token.text == "*" || token.text == "_") {
      // Check if this could be a thematic break (need at least 3 characters)
      var count = 0
      var i = index
      while i < tokens.count && tokens[i].element == .punctuation && tokens[i].text == token.text {
        count += 1
        i += 1
      }
      if count >= 3 {
        return true
      }
    }
    
    // HTML blocks starting with <
    if token.element == .punctuation && token.text == "<" {
      return true
    }
    
    return false
  }
  
  /// Calculate leading indentation accounting for spaces and tabs
  private func calculateLeadingIndentation(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Int {
    var leadingSpaces = 0
    if let firstToken = tokens.first, firstToken.element == .whitespaces {
      for ch in firstToken.text {
        if ch == " " {
          leadingSpaces += 1
        } else if ch == "\t" {
          leadingSpaces += 4 // Tab equals 4 spaces
        }
      }
    }
    return leadingSpaces
  }
  
  /// Determine if content should continue in the given list context
  private func shouldContinueInListContext(
    leadingIndent: Int,
    contextInfo: ListContextInfo,
    tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> Bool {
    // Content needs at least the content indentation of the list context
    if leadingIndent >= contextInfo.contentIndent {
      // Sufficient indentation for this context level
      return true
    }
    
    // Check for lazy continuation (CommonMark allows this in some cases)
    // But be more restrictive - only allow lazy continuation if:
    // 1. There's some indentation (> 0)
    // 2. There's actual content (not just whitespace)
    // 3. The indentation is reasonable (not too much less than required)
    if leadingIndent > 0 && 
       hasNonWhitespaceAfterFirst(tokens) &&
       leadingIndent >= (contextInfo.contentIndent - 2) { // Allow up to 2 spaces less for lazy continuation
      return true
    }
    
    return false
  }
  
  /// Find the appropriate list item to continue based on indentation and context
  private func findTargetListItemForContinuation(
    contextInfo: ListContextInfo,
    leadingIndent: Int,
    constructContext: CodeConstructContext<Node, Token>
  ) -> ListItemNode? {
    // Start from the current context and find the most appropriate list item
    
    // If we're already in a list item, check if we should continue it or a parent
    if let currentListItem = constructContext.current as? ListItemNode {
      // Check if indentation matches this list item's content indent
      if leadingIndent >= currentListItem.contentIndent {
        return currentListItem
      }
      
      // Check parent list items for proper nesting level
      var parentNode = currentListItem.parent
      while let node = parentNode {
        if let parentListItem = node.parent as? ListItemNode {
          if leadingIndent >= parentListItem.contentIndent {
            return parentListItem
          }
        }
        parentNode = node.parent
      }
    }
    
    // Fallback: use the last item in the context list
    return contextInfo.list.children.last as? ListItemNode
  }
  
  /// Handle paragraph continuation vs creation within a list item
  private func handleParagraphContinuationInListItem(
    _ listItem: ListItemNode,
    state: MarkdownConstructState,
    hasBlankLineBefore: Bool
  ) {
    if hasBlankLineBefore {
      // Blank line before: create new paragraph instead of continuing existing one
      // Don't set current to existing paragraph - let paragraph builder create new one
      state.lastWasBlankLine = false // Reset the flag
    } else {
      // No blank line: try to continue existing paragraph
      if let lastParagraph = listItem.children.last as? ParagraphNode {
        // Let paragraph builder handle the continuation
        // We don't force context here to allow proper paragraph building
      }
    }
  }

  // MARK: - New List Item Detection and Creation (from original MarkdownListItemBuilder)
  
  private func handleNewListItem(
    markerInfo: ListMarkerInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
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

  private func detectListMarker(
    tokens: [any CodeToken<MarkdownTokenElement>],
    startIndex: Int
  ) -> ListMarkerInfo? {
    var index = startIndex
    var indentation = 0

    // Count leading indentation
    // Note: We don't enforce the 3-space limit here for nested contexts
    // That validation should be done by the context determination logic
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      let spaceCount = tokens[index].text.count
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
        // Before treating as list marker, check if this might be a thematic break
        if couldBeThematicBreak(tokens: tokens, startIndex: startIndex, markerChar: markerToken.text) {
          return nil  // Let thematic break builder handle this
        }
        
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

    // Create list item with enhanced indentation calculation
    let listItem = createListItemWithProperIndent(markerInfo: markerInfo, list: list, state: state)
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
    
    // Update enhanced context stack
    updateListContextStack(list: list, state: state)
  }
  
  /// Update the enhanced context stack with proper indentation and level information
  private func updateListContextStack(list: ListNode, state: MarkdownConstructState) {
    let parentListItem = findParentListItem(for: list)
    let level = state.listContextStack.count + 1
    let markerType = getListMarkerType(list)
    let contentIndent = calculateContentIndent(for: list, parentListItem: parentListItem, level: level)
    
    let contextInfo = ListContextInfo(
      list: list,
      parentListItem: parentListItem,
      contentIndent: contentIndent,
      level: level,
      markerType: markerType
    )
    
    // Remove any invalid contexts that are no longer ancestors
    state.listContextStack = state.listContextStack.filter { context in
      var current: CodeNode<MarkdownNodeElement>? = list
      while let node = current {
        if node === context.list {
          return true
        }
        current = node.parent
      }
      return false
    }
    
    // Add new context
    state.listContextStack.append(contextInfo)
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

  // MARK: - Helper Methods

  private func startsWithListOrQuoteMarker(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var i = 0
    // skip up to 3 spaces
    var spaces = 0
    if i < tokens.count && tokens[i].element == .whitespaces {
      for ch in tokens[i].text { 
        if ch == " " { spaces += 1 } 
        else if ch == "\t" { spaces += 4 } 
      }
      if spaces > 3 { return false }
      i += 1
    }
    guard i < tokens.count else { return false }
    let t = tokens[i]
    if t.element == .punctuation && (t.text == ">" || t.text == "-" || t.text == "*" || t.text == "+") {
      return true
    }
    if t.element == .characters, let _ = Int(t.text), i + 1 < tokens.count {
      let del = tokens[i+1]
      if del.element == .punctuation && (del.text == "." || del.text == ")") { return true }
    }
    return false
  }

  private func nearestListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
    var cur: CodeNode<MarkdownNodeElement>? = node
    while let n = cur {
      if let li = n as? ListItemNode { return li }
      cur = n.parent
    }
    return nil
  }

  // Check if there is any non-whitespace token after the first token (which may be indentation)
  private func hasNonWhitespaceAfterFirst(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    if tokens.isEmpty { return false }
    var i = 0
    if tokens[0].element == .whitespaces { i = 1 }
    while i < tokens.count {
      let t = tokens[i]
      if t.element != .whitespaces { return true }
      i += 1
    }
    return false
  }
  
  /// Check if a line could be a thematic break pattern instead of a list
  private func couldBeThematicBreak(tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int, markerChar: String) -> Bool {
    var index = startIndex
    var charCount = 0
    var hasOnlyMarkerAndSpaces = true
    
    // Skip leading whitespace (up to 3 spaces allowed for thematic breaks)
    var leadingSpaces = 0
    while index < tokens.count, tokens[index].element == .whitespaces {
      let spaceCount = tokens[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return false  // Too much indentation for thematic break
      }
      leadingSpaces += spaceCount
      index += 1
    }
    
    // Count occurrences of the marker character and check for other content
    while index < tokens.count {
      let token = tokens[index]
      
      switch token.element {
      case .punctuation:
        if token.text == markerChar {
          charCount += 1
        } else {
          // Other punctuation characters disqualify it as thematic break
          hasOnlyMarkerAndSpaces = false
        }
      case .whitespaces:
        // Spaces are allowed between marker characters
        break
      case .newline, .eof:
        // End of line - we can make the determination
        break
      default:
        // Any other content disqualifies it as thematic break
        hasOnlyMarkerAndSpaces = false
      }
      
      index += 1
    }
    
    // Thematic break requires at least 3 marker characters and only marker + spaces
    return charCount >= 3 && hasOnlyMarkerAndSpaces
  }
}

// MARK: - Helper Types

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
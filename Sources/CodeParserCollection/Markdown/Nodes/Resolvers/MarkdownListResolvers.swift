import CodeParserCore
import Foundation

private func whitespaceWidth(_ text: String) -> Int {
  var width = 0
  for ch in text {
    if ch == "\t" {
      let nextTab = ((width / 4) + 1) * 4
      width = nextTab
    } else {
      width += 1
    }
  }
  return width
}

// MARK: - Unordered List Resolvers

public class MarkdownUnorderedListCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }

    let remainingTokens = Array(context.tokens[context.consumed...])

    if context.current.element == .paragraph, let item = ancestorListItem(from: context.current) {
      let (spaces, _, _) = MarkdownIndentation.calculateIndentation(from: remainingTokens)
      if spaces < item.contentIndent && spaces - item.markerIndent <= 3 {
        return false
      }
    }

    let allowIndented = ancestorListItem(from: context.current) != nil
    guard
      let marker = MarkdownListUtils.detectUnorderedMarker(
        tokens: remainingTokens, allowIndented: allowIndented)
    else { return false }

    let tokens = remainingTokens
    var markerIndex = 0
    while markerIndex < tokens.count && tokens[markerIndex].element == .whitespace {
      markerIndex += 1
    }
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)

    // Adjust current node for paragraph or differing marker
    if context.current.element == .paragraph, let p = context.current.parent as? MarkdownNodeBase {
      context.current = p
    }
    if let list = context.current as? UnorderedListNode, list.marker != marker.marker,
      let parent = list.parent as? MarkdownNodeBase
    {
      context.current = parent
    }

    // Determine parent and level with shared indentation logic
    guard let (resolvedParent, level) = determineListParent(&context, leadingSpaces: leadingSpaces)
    else { return false }

    let listNode = UnorderedListNode(level: level, marker: marker.marker)
    resolvedParent.append(listNode)
    let itemNode = ListItemNode(marker: marker.marker)
    itemNode.markerIndent = leadingSpaces
    // Count consecutive spaces after marker with single-character tokens
    var spacesAfter = 0
    var j = markerIndex + 1
    while j < tokens.count && tokens[j].element == .whitespace && tokens[j].text == " " {
      spacesAfter += 1
      j += 1
    }
    if spacesAfter == 0 { spacesAfter = 1 } // Default minimum
    itemNode.contentIndent = leadingSpaces + 1 + spacesAfter
    itemNode.markerColumn = leadingSpaces
    itemNode.contentColumn = itemNode.contentIndent
    itemNode.markerLength = 1
    listNode.append(itemNode)
    context.current = itemNode
    // Consume the list marker and all spaces up to content indent
    context.consumed += itemNode.contentIndent
    context.refreshed = true
    return true
  }
}

public class MarkdownUnorderedListContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let remainingTokens = Array(context.tokens[context.consumed...])

    // Check if we need to strip list item indentation for content processing
    if let listItem = context.current as? ListItemNode {
      let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: remainingTokens)
      if leadingSpaces >= listItem.contentIndent && context.consumed == 0 {
        // Strip list item indentation by advancing consumed pointer (only if not already stripped)
        context.consumed += listItem.contentIndent
        // Don't refresh - just let other resolvers process the remaining tokens
        return false
      }
    }

    guard let (list, item) = currentListContext(from: context.current) else { return false }

    let tokens = remainingTokens
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if leadingSpaces >= item.contentIndent { return false }
    if leadingSpaces > 3 { return false }

    guard let marker = MarkdownListUtils.detectUnorderedMarker(tokens: tokens, allowIndented: true),
      let ulist = list as? UnorderedListNode,
      marker.marker == ulist.marker
    else { return false }

    context.current = list
    let newItem = ListItemNode(marker: marker.marker)
    var markerIndex = 0
    while markerIndex < tokens.count && tokens[markerIndex].element == .whitespace {
      markerIndex += 1
    }
    // Count consecutive spaces after marker with single-character tokens
    var spacesAfter = 0
    var j = markerIndex + 1
    while j < tokens.count && tokens[j].element == .whitespace && tokens[j].text == " " {
      spacesAfter += 1
      j += 1
    }
    if spacesAfter == 0 { spacesAfter = 1 } // Default minimum
    newItem.markerIndent = leadingSpaces
    newItem.contentIndent = leadingSpaces + 1 + spacesAfter
    newItem.markerColumn = leadingSpaces
    newItem.contentColumn = newItem.contentIndent
    newItem.markerLength = 1
    list.append(newItem)
    context.current = newItem
    // Consume the list marker
    context.consumed += marker.nextIndex
    context.refreshed = true
    return true
  }
}

public class MarkdownUnorderedListConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    return false
  }
}

// MARK: - Ordered List Resolvers

public class MarkdownOrderedListCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }

    let remainingTokens = Array(context.tokens[context.consumed...])

    if context.current.element == .paragraph, let item = ancestorListItem(from: context.current) {
      let (spaces, _, _) = MarkdownIndentation.calculateIndentation(from: remainingTokens)
      if spaces < item.contentIndent && spaces - item.markerIndent <= 3 {
        return false
      }
    }

    let allowIndented = ancestorListItem(from: context.current) != nil
    guard
      let info = MarkdownListUtils.detectOrderedMarker(
        tokens: remainingTokens, allowIndented: allowIndented)
    else { return false }
    if context.current.element == .paragraph && ancestorListItem(from: context.current) == nil
      && info.numberText != "1"
    {
      return false
    }

    let tokens = remainingTokens
    var markerIndex = 0
    while markerIndex < tokens.count && tokens[markerIndex].element == .whitespace {
      markerIndex += 1
    }
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    let startNumber = Int(info.numberText) ?? 1

    // Adjust current node for paragraph or differing list characteristics
    if context.current.element == .paragraph, let p = context.current.parent as? MarkdownNodeBase {
      context.current = p
    }
    if let list = context.current as? OrderedListNode,
      startNumber != list.start || info.delimiter != list.delimiter,
      let parent = list.parent as? MarkdownNodeBase
    {
      context.current = parent
    }

    // Determine parent and level with shared indentation logic
    guard let (resolvedParent, level) = determineListParent(&context, leadingSpaces: leadingSpaces)
    else { return false }

    let start = startNumber
    let listNode = OrderedListNode(start: start, level: level, delimiter: info.delimiter)
    resolvedParent.append(listNode)
    let itemNode = ListItemNode(marker: info.numberText + info.delimiter)
    // Count consecutive spaces after marker with single-character tokens
    var spacesAfter = 0
    var j = markerIndex + 2  // Skip number and delimiter
    while j < tokens.count && tokens[j].element == .whitespace && tokens[j].text == " " {
      spacesAfter += 1
      j += 1
    }
    if spacesAfter == 0 { spacesAfter = 1 } // Default minimum
    itemNode.markerIndent = leadingSpaces
    itemNode.contentIndent =
      leadingSpaces + info.numberText.count + info.delimiter.count + spacesAfter
    itemNode.markerColumn = leadingSpaces
    itemNode.contentColumn = itemNode.contentIndent
    itemNode.markerLength = info.numberText.count + info.delimiter.count
    listNode.append(itemNode)
    context.current = itemNode
    // Consume the list marker and all spaces up to content indent
    context.consumed += itemNode.contentIndent
    context.refreshed = true
    return true
  }
}

public class MarkdownOrderedListContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let remainingTokens = Array(context.tokens[context.consumed...])

    // Check if we need to strip list item indentation for content processing
    if let listItem = context.current as? ListItemNode {
      let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: remainingTokens)
      if leadingSpaces >= listItem.contentIndent && context.consumed == 0 {
        // Strip list item indentation by advancing consumed pointer (only if not already stripped)
        context.consumed += listItem.contentIndent
        // Don't refresh - just let other resolvers process the remaining tokens
        return false
      }
    }

    guard let (list, item) = currentListContext(from: context.current),
      let olist = list as? OrderedListNode
    else { return false }

    let tokens = remainingTokens
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if leadingSpaces >= item.contentIndent { return false }
    if leadingSpaces > 3 { return false }

    guard let info = MarkdownListUtils.detectOrderedMarker(tokens: tokens, allowIndented: true),
      info.delimiter == olist.delimiter
    else { return false }
    context.current = list
    let newItem = ListItemNode(marker: info.numberText + info.delimiter)
    var markerIndex = 0
    while markerIndex < tokens.count && tokens[markerIndex].element == .whitespace {
      markerIndex += 1
    }
    // Count consecutive spaces after marker with single-character tokens
    var spacesAfter = 0
    var j = markerIndex + 2  // Skip number and delimiter
    while j < tokens.count && tokens[j].element == .whitespace && tokens[j].text == " " {
      spacesAfter += 1
      j += 1
    }
    if spacesAfter == 0 { spacesAfter = 1 } // Default minimum
    newItem.markerIndent = leadingSpaces
    newItem.contentIndent =
      leadingSpaces + info.numberText.count + info.delimiter.count + spacesAfter
    newItem.markerColumn = leadingSpaces
    newItem.contentColumn = newItem.contentIndent
    newItem.markerLength = info.numberText.count + info.delimiter.count
    list.append(newItem)
    context.current = newItem
    // Consume the list marker
    context.consumed += info.nextIndex
    context.refreshed = true
    return true
  }
}

public class MarkdownOrderedListConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    return false
  }
}

// MARK: - Helpers


private func ancestorListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
  var cur = node as? MarkdownNodeBase
  while let c = cur {
    if let item = c as? ListItemNode { return item }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}

private func currentListContext(from node: CodeNode<MarkdownNodeElement>) -> (
  ListNode, ListItemNode
)? {
  // If node is a list, use its last item as context when available
  if let list = node as? ListNode, let last = list.children.last as? ListItemNode {
    return (list, last)
  }
  var cur = node as? MarkdownNodeBase
  var foundItem: ListItemNode?
  while let c = cur {
    if foundItem == nil, let item = c as? ListItemNode { foundItem = item }
    if let list = c as? ListNode, let item = foundItem { return (list, item) }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}

private func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  for t in tokens {
    if t.element != .whitespace && t.element != .newline && t.element != .eof {
      return false
    }
  }
  return true
}

// Shared helper to determine the parent node and resulting list level
private func determineListParent(_ context: inout MarkdownBlockContext, leadingSpaces: Int) -> (
  MarkdownNodeBase, Int
)? {
  let cur = context.current
  var parent = cur as? MarkdownNodeBase
  if let (list, item) = currentListContext(from: cur) {
    if leadingSpaces >= item.contentIndent {
      parent = item
      context.current = item
    } else {
      parent = list
      context.current = list
    }
  }
  guard let resolved = parent else { return nil }
  let level: Int
  if let list = resolved as? ListNode {
    level = list.level
  } else if let item = resolved as? ListItemNode, let list = item.parent as? ListNode {
    level = list.level + 1
  } else {
    level = 1
  }
  return (resolved, level)
}

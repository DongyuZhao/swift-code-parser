import CodeParserCore
import Foundation

// MARK: - Unordered List Resolvers

public class MarkdownUnorderedListCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }
    let allowIndented = ancestorListItem(from: context.current) != nil
    guard let marker = MarkdownListUtils.detectUnorderedMarker(tokens: context.tokens, allowIndented: allowIndented) else { return false }
    var cur = context.current
    if cur.element == .paragraph, let p = cur.parent as? MarkdownNodeBase {
      cur = p
      context.current = p
    }
    guard let parent = cur as? MarkdownNodeBase else { return false }
    let level: Int
    if let list = parent as? ListNode {
      level = list.level
    } else if let item = parent as? ListItemNode, let list = item.parent as? ListNode {
      level = list.level + 1
    } else {
      level = 1
    }
    let listNode = UnorderedListNode(level: level, marker: marker.marker)
    parent.append(listNode)
    let item = ListItemNode(marker: marker.marker)
    listNode.append(item)
    context.current = item
    context.tokens = Array(context.tokens[marker.nextIndex...])
    return true
  }
}

public class MarkdownUnorderedListContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let (list, _) = currentListContext(from: context.current) else { return false }
    guard let marker = MarkdownListUtils.detectUnorderedMarker(tokens: context.tokens, allowIndented: true),
          let ulist = list as? UnorderedListNode,
          marker.marker == ulist.marker else { return false }
    context.current = list
    let newItem = ListItemNode(marker: marker.marker)
    list.append(newItem)
    context.current = newItem
    context.tokens = Array(context.tokens[marker.nextIndex...])
    return true
  }
}

public class MarkdownUnorderedListConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let item = context.current as? ListItemNode else { return false }
    let tokens = context.tokens
    if isBlankLine(tokens) { return true }
    let paragraph: ParagraphNode
    if let last = item.children.last as? ParagraphNode {
      paragraph = last
    } else {
      let range = tokens.first?.range ?? tokens.last?.range ?? ("".startIndex..<("".startIndex))
      paragraph = ParagraphNode(range: range)
      item.append(paragraph)
    }
    paragraph.append(ContentNode(tokens: tokens))
    context.current = paragraph
    return true
  }
}

// MARK: - Ordered List Resolvers

public class MarkdownOrderedListCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }
    let allowIndented = ancestorListItem(from: context.current) != nil
    guard let info = MarkdownListUtils.detectOrderedMarker(tokens: context.tokens, allowIndented: allowIndented) else { return false }
    var cur = context.current
    if cur.element == .paragraph, let p = cur.parent as? MarkdownNodeBase {
      cur = p
      context.current = p
    }
    guard let parent = cur as? MarkdownNodeBase else { return false }
    let level: Int
    if let list = parent as? ListNode {
      level = list.level
    } else if let item = parent as? ListItemNode, let list = item.parent as? ListNode {
      level = list.level + 1
    } else {
      level = 1
    }
    let start = Int(info.numberText) ?? 1
    let listNode = OrderedListNode(start: start, level: level, delimiter: info.delimiter)
    parent.append(listNode)
    let item = ListItemNode(marker: info.numberText + info.delimiter)
    listNode.append(item)
    context.current = item
    context.tokens = Array(context.tokens[info.nextIndex...])
    return true
  }
}

public class MarkdownOrderedListContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let (list, _) = currentListContext(from: context.current),
          let olist = list as? OrderedListNode else { return false }
    guard let info = MarkdownListUtils.detectOrderedMarker(tokens: context.tokens, allowIndented: true),
          info.delimiter == olist.delimiter else { return false }
    context.current = list
    let item = ListItemNode(marker: info.numberText + info.delimiter)
    list.append(item)
    context.current = item
    context.tokens = Array(context.tokens[info.nextIndex...])
    return true
  }
}

public class MarkdownOrderedListConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let item = context.current as? ListItemNode else { return false }
    let tokens = context.tokens
    if isBlankLine(tokens) { return true }
    let paragraph: ParagraphNode
    if let last = item.children.last as? ParagraphNode {
      paragraph = last
    } else {
      let range = tokens.first?.range ?? tokens.last?.range ?? ("".startIndex..<("".startIndex))
      paragraph = ParagraphNode(range: range)
      item.append(paragraph)
    }
    paragraph.append(ContentNode(tokens: tokens))
    context.current = paragraph
    return true
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

private func currentListContext(from node: CodeNode<MarkdownNodeElement>) -> (ListNode, ListItemNode)? {
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
    if t.element != .whitespaces && t.element != .newline && t.element != .eof {
      return false
    }
  }
  return true
}


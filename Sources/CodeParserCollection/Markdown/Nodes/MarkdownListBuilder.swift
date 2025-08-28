import CodeParserCore
import Foundation

/// Handles list continuation and manages list state
/// Works in conjunction with MarkdownListItemBuilder
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#lists  
public class MarkdownListBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
  guard context.state is MarkdownConstructState else {
      return false
    }

    // This builder handles list continuation and lazy continuation
    // The actual list item creation is handled by MarkdownListItemBuilder
    
    // Check if we're currently in a list context and need to handle continuation
    if let currentList = context.current as? ListNode {
      return handleListContinuation(inList: currentList, context: &context)
    }
    // Also handle when current is inside a list item or paragraph under it
    if let li = nearestListItem(from: context.current) {
      return handleListContinuation(inItem: li, context: &context)
    }
    
    return false
  }
  
  private func handleListContinuation(
    inList list: ListNode,
    context: inout CodeConstructContext<Node, Token>
  ) -> Bool {
    // If the current is the list container, try to continue the last item
    guard let lastItem = list.children.last as? ListItemNode else { return false }
    return handleListContinuation(inItem: lastItem, context: &context)
  }

  private func handleListContinuation(
    inItem listItem: ListItemNode,
    context: inout CodeConstructContext<Node, Token>
  ) -> Bool {
    let tokens = context.tokens
    guard !tokens.isEmpty else {
      // Blank line within list item: let leaf builders handle closing/opening paragraphs
      return true
    }

    // If this line begins with a new list marker or blockquote marker, do not treat as continuation
    if startsWithListOrQuoteMarker(tokens) {
      return false
    }

    // Count leading spaces
    var leadingSpaces = 0
    if tokens.first?.element == .whitespaces {
      for ch in tokens.first!.text { if ch == " " { leadingSpaces += 1 } else if ch == "\t" { leadingSpaces += 4 } }
    }

    // Continuation requires sufficient indentation relative to marker width
  if leadingSpaces >= listItem.contentIndent || (leadingSpaces > 0 && hasNonWhitespaceAfterFirst(tokens)) {
      // Ensure we are at the paragraph under this list item for paragraph continuation
      if let lastParagraph = listItem.children.last as? ParagraphNode {
        context.current = lastParagraph
      } else {
        let p = ParagraphNode(range: "".startIndex..<"".endIndex)
        listItem.append(p)
        context.current = p
      }
      // Do not set refreshed; allow leafOnLine ParagraphBuilder to consume this line
      return true
    }

    return false
  }

  private func startsWithListOrQuoteMarker(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    var i = 0
    // skip up to 3 spaces
    var spaces = 0
    if i < tokens.count && tokens[i].element == .whitespaces {
      for ch in tokens[i].text { if ch == " " { spaces += 1 } else if ch == "\t" { spaces += 4 } }
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
}
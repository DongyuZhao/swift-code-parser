import CodeParserCore
import Foundation

/// Recognizes thematic breaks (***, --- or ___ with optional spaces) as standalone blocks.
public class MarkdownThematicBreakCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Do not recognize thematic breaks inside code blocks
    guard context.current.element != .codeBlock else { return false }

    let tokens = context.tokens
    var i = 0

    // Skip up to 3 leading spaces
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return false }
      i += 1
    }

    // Accept a sequence of at least 3 identical '-', '_' or '*', possibly separated by spaces
    func isMarker(_ s: String) -> Bool { s == "-" || s == "_" || s == "*" }
    var marker: String? = nil
    var count = 0
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .whitespaces { i += 1; continue }
      if t.element == .punctuation, isMarker(t.text) {
        if marker == nil { marker = t.text }
        if t.text != marker { return false }
        count += 1
        i += 1
        continue
      }
      if t.element == .newline || t.element == .eof { break }
      return false
    }
    guard count >= 3, marker != nil else { return false }

    var target = context.current
    // A thematic break interrupts a paragraph inside a list item, but can also
    // appear as content of a list item. Pop out when we're in a paragraph within
    // a list item or when the list item already has content (meaning the break
    // should end the list).
    if target.element == .paragraph, let p = target.parent, p.element == .listItem {
      if let list = p.parent {
        target = list.parent ?? list
      } else {
        target = p.parent ?? p
      }
      context.current = target
    } else if target.element == .listItem,
              let item = target as? MarkdownNodeBase, !item.children.isEmpty {
      if let list = item.parent {
        target = list.parent ?? list
      } else {
        target = item.parent ?? item
      }
      context.current = target
    }
    if let parent = target as? MarkdownNodeBase {
      parent.append(ThematicBreakNode())
      // Consume the line so no further resolvers act on it
      context.tokens = []
      return true
    }
    return false
  }
}

/// Thematic breaks are single-line blocks and do not continue; ensure current
/// is at the correct container by popping if it somehow points at the break.
public class MarkdownThematicBreakContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Ignore EOF-only line
    if context.tokens.count == 1, context.tokens.first?.element == .eof { return false }

    if context.current.element == .thematicBreak, let parent = context.current.parent {
      context.current = parent
      return true
    }
    return false
  }
}

/// Construction resolver for Thematic Breaks. There is no leaf content on this line.
public class MarkdownThematicBreakConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

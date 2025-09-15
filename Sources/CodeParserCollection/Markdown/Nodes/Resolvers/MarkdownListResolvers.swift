import CodeParserCore
import Foundation

/// Minimal unordered list resolvers needed for setext heading tests.
public class MarkdownUnorderedListCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Lists should not start inside code blocks or paragraphs already handled
    guard context.current.element != .codeBlock else { return false }
    let tokens = context.tokens
    var i = 0
    // Up to three leading spaces
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return false }
      i += 1
    }
    guard i < tokens.count else { return false }
    let t = tokens[i]
    guard t.element == .punctuation, t.text == "-" || t.text == "*" || t.text == "+" else { return false }
    let marker = t.text
    i += 1
    // Require at least one space or end of line after marker
    if i >= tokens.count { return false }
    let next = tokens[i]
    if next.element == .whitespaces { i += 1 }
    else if next.element != .newline && next.element != .eof { return false }

    // Ensure the line isn't an alternative thematic break like "* * *"
    if i < tokens.count {
      let after = tokens[i]
      if after.element == .punctuation && (after.text == "-" || after.text == "*" || after.text == "+") {
        return false
      }
    }

    guard let parent = context.current as? MarkdownNodeBase else { return false }
    let list = UnorderedListNode(level: 1, marker: marker)
    parent.append(list)
    let item = ListItemNode(marker: marker)
    list.append(item)
    context.current = item
    // Yield remaining tokens (after marker and following space) for further processing
    context.tokens = Array(tokens[i...])
    context.refreshed = true
    return true
  }
}

public class MarkdownUnorderedListContinuationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

public class MarkdownUnorderedListConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

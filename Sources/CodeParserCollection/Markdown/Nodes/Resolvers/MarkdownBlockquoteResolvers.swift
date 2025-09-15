import CodeParserCore
import Foundation

/// Minimal blockquote resolvers supporting single-level blockquotes
/// used in setext heading tests.
public class MarkdownBlockquoteCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Do not start a blockquote within a code block
    guard context.current.element != .codeBlock else { return false }
    let tokens = context.tokens
    let (depth, endIndex) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
    guard depth > 0 else { return false }
    guard let parent = context.current as? MarkdownNodeBase else { return false }
    let bq = BlockquoteNode(level: depth)
    parent.append(bq)
    context.current = bq
    // Yield remaining tokens to be processed inside blockquote
    context.tokens = Array(tokens[endIndex...])
    context.refreshed = true
    return true
  }
}

public class MarkdownBlockquoteContinuationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Only handle when current is a blockquote container
    guard context.current.element == .blockquote else { return false }
    let tokens = context.tokens
    let (depth, endIndex) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
    if depth > 0 {
      // Consume one marker level and reprocess remaining tokens
      context.tokens = Array(tokens[endIndex...])
      context.refreshed = true
      return true
    }
    // Blank lines keep the blockquote open
    var isBlank = true
    for t in tokens {
      if t.element != .whitespaces && t.element != .newline && t.element != .eof {
        isBlank = false
        break
      }
    }
    if isBlank { return true }
    // Line without marker ends the blockquote
    if let parent = context.current.parent {
      context.current = parent
      context.refreshed = true
    }
    return true
  }
}

public class MarkdownBlockquoteConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

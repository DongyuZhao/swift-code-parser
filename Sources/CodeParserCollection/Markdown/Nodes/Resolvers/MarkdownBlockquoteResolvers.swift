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
    // Handle when current is blockquote or its child
    let inChild = context.current.element != .blockquote
    if inChild {
      guard context.current.parent?.element == .blockquote else { return false }
    }
    let tokens = context.tokens
    let (depth, endIndex) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
    if depth > 0 {
      // Strip blockquote markers and continue processing remaining tokens in
      // the same iteration so other resolvers (like code blocks) can act on
      // them.
      context.tokens = Array(tokens[endIndex...])
      return false
    }
    if inChild {
      // If the current child is a paragraph, allow lazy continuation without a
      // '>' marker by keeping context unchanged so paragraph resolvers can
      // process the line inside the blockquote.
      if context.current.element == .paragraph {
        return false
      }
      // Otherwise we're leaving the blockquote: pop to its parent so that
      // subsequent resolvers see the line in the outer context (closing any
      // nested constructs like fenced code blocks).
      if let grand = context.current.parent?.parent {
        context.current = grand
      } else if let parent = context.current.parent {
        context.current = parent
      }
      context.refreshed = true
      return true
    }
    var isBlank = true
    for t in tokens {
      if t.element != .whitespaces && t.element != .newline && t.element != .eof {
        isBlank = false
        break
      }
    }
    if isBlank { return true }
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

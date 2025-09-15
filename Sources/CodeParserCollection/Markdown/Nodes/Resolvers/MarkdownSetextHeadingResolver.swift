import CodeParserCore
import Foundation

/// Creation resolver for Setext headings. When encountering an underline line
/// of '=' or '-' (with up to three leading spaces and optional trailing spaces),
/// converts the last paragraph child of the current container into a heading
/// (level 1 for '=', level 2 for '-').
public class MarkdownSetextHeadingCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let tokens = context.tokens

    guard let level = MarkdownSetextUtils.headingLevel(for: tokens) else { return false }

    // Setext headings transform the _current_ paragraph. Ensure the
    // current node is a paragraph and we have access to its parent
    // container to perform the replacement.
    guard
      let paragraph = context.current as? MarkdownNodeBase,
      paragraph.element == .paragraph,
      let container = paragraph.parent as? MarkdownNodeBase,
      let index = container.children.firstIndex(where: { $0 === paragraph })
    else {
      return false
    }

    // Do not transform if inside a blockquote where the underline line is a
    // lazy continuation (i.e., the line lacks '>'). In that case the underline
    // should be treated as regular text.
    let (bqDepth, _) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
    if container.element == .blockquote && bqDepth == 0 {
      return false
    }

    // Create heading node with the detected level
    let heading = HeaderNode(level: level)

    // Move existing children from the paragraph to the new heading
    let moved = paragraph.children
    paragraph.children.removeAll()
    for child in moved {
      if let m = child as? MarkdownNodeBase {
        heading.append(m)
      } else {
        heading.append(child)
      }
    }

    // Replace the paragraph in its parent with the heading
    container.replace(at: index, with: heading)

    // After replacement, the current context should move back to the parent
    context.current = container
    return true
  }

}

/// Continuation resolver for Setext headings. Setext headings are resolved by transforming
/// an existing paragraph, so there is no ongoing container to continue. This is a no-op.
public class MarkdownSetextHeadingContinuationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

/// Construction resolver for Setext headings. There is no leaf content to attach on the underline line.
/// This is a no-op and returns false.
public class MarkdownSetextHeadingConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool { return false }
}

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

    // Find the last paragraph child in the current container
    guard let container = context.current as? MarkdownNodeBase else { return false }
    guard let lastIndex = container.children.lastIndex(where: { $0.element == .paragraph }),
          let paragraph = container.children[lastIndex] as? MarkdownNodeBase else {
      return false
    }

    // Transform paragraph -> heading(level)
    let heading = HeaderNode(level: level)
    // Move children from paragraph to heading
    let movedChildren = paragraph.children
    paragraph.children.removeAll()
    for child in movedChildren {
      if let mChild = child as? MarkdownNodeBase {
        heading.append(mChild)
      } else {
        heading.append(child)
      }
    }
    // Replace paragraph with heading in container
    container.replace(at: lastIndex, with: heading)

    // Keep context.current at container (headings are single-line blocks)
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

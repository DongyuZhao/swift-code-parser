import CodeParserCore
import Foundation

/// Handles HTML comment blocks like <!-- -->
public class MarkdownHTMLBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.state is MarkdownConstructState else { return false }
    guard !context.tokens.isEmpty else { return false }

    // Reconstruct the raw line (excluding trailing newline)
    var line = ""
    for t in context.tokens {
      if t.element == .newline { break }
      switch t.element {
      case .characters, .punctuation, .whitespaces, .charef:
        line += t.text
      default:
        break
      }
    }

    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") else { return false }

    // Close paragraph if inside one
    if context.current.element == .paragraph, let parent = context.current.parent {
      context.current = parent
    }

    // Place at document level if inside container structures
    if isInsideContainer(context: context) {
      context.current = findDocumentLevel(context: context)
    }

    let html = HTMLBlockNode(name: "", content: trimmed)
    context.current.append(html)
    return true
  }

  private func isInsideContainer(context: CodeConstructContext<Node, Token>) -> Bool {
    var current: MarkdownNodeBase? = context.current as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode || node is ListItemNode || node is ListNode {
        return true
      }
      current = node.parent()
    }
    return false
  }

  private func findDocumentLevel(context: CodeConstructContext<Node, Token>) -> CodeNode<MarkdownNodeElement> {
    var current = context.current
    while let parent = current.parent {
      if let markdownParent = parent as? MarkdownNodeBase,
         !(markdownParent is BlockquoteNode) && !(markdownParent is ListItemNode) && !(markdownParent is ListNode) {
        return parent
      }
      current = parent
    }
    return current
  }
}

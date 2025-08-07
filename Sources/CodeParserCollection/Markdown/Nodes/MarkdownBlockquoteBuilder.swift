import CodeParserCore
import Foundation

public class MarkdownBlockquoteBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .gt,
      isStartOfLine(context)
    else { return false }

    context.consuming += 1
    // optional leading space
    if context.consuming < context.tokens.count,
      let space = context.tokens[context.consuming] as? MarkdownToken,
      space.element == .space
    {
      context.consuming += 1
    }

    // Check if the last child is already a blockquote that we can continue
    let node: BlockquoteNode
    if let lastChild = context.current.children.last as? BlockquoteNode {
      node = lastChild
    } else {
      node = BlockquoteNode()
      context.current.append(node)
    }

    let paragraph = ParagraphNode(range: token.range)
    var inlineCtx = CodeConstructContext(
      current: paragraph,
      tokens: context.tokens,
      consuming: context.consuming,
      state: context.state
    )
    let inlineBuilder = MarkdownInlineBuilder()
    _ = inlineBuilder.build(from: &inlineCtx)
    context.consuming = inlineCtx.consuming
    node.append(paragraph)

    if context.consuming < context.tokens.count,
      let nl = context.tokens[context.consuming] as? MarkdownToken,
      nl.element == .newline
    {
      context.consuming += 1
    }
    return true
  }

  private func isStartOfLine(
    _ context: CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    if context.consuming == 0 { return true }
    if let prev = context.tokens[context.consuming - 1] as? MarkdownToken {
      return prev.element == .newline
    }
    return false
  }
}

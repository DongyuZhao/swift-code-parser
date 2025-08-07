import CodeParserCore
import Foundation

/// Consumes trailing EOF tokens without modifying the AST.
public class MarkdownEOFBuilder: CodeNodeBuilder {
  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count,
      let token = context.tokens[context.consuming] as? MarkdownToken,
      token.element == .eof
    else { return false }
    context.consuming += 1

    // Post-processing: resolve reference links (case-insensitive, empty label support)
    var root = context.current
    while let parent = root.parent { root = parent }
    MarkdownReferenceResolver.resolve(in: root)
    return true
  }
}

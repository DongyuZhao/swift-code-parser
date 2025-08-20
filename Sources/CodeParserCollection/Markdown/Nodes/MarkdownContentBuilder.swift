import CodeParserCore
import Foundation

public class MarkdownContentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Traverse the AST to parse all the content nodes
    context.root.dfs { node in
      if let node = node as? ContentNode {
        process(node)
      }
    }
    return true
  }

  // Delimiter stack based inline processing
  // Emphasis, Strong, link, autolink, autolink GFM, image, code span, html
  private func process(_ node: ContentNode) {
    // TODO: Implement delimiter stack based inline processing
  }
}

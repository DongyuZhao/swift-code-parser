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
    resolveReferenceLinks(in: context.current)
    return true
  }

  private func resolveReferenceLinks(in root: CodeNode<MarkdownNodeElement>) {
    // Collect definitions (case-insensitive key)
    var definitions: [String: ReferenceNode] = [:]
    collectDefinitions(node: root, into: &definitions)
    // Walk and replace ReferenceNode that acts as usage (identifier may be empty => use its text content)
    replaceReferences(node: root, definitions: definitions)
  }

  private func collectDefinitions(
    node: CodeNode<MarkdownNodeElement>, into map: inout [String: ReferenceNode]
  ) {
    for child in node.children {
      if let ref = child as? ReferenceNode, !ref.url.isEmpty { // definition
        let key = ref.identifier.lowercased()
        if map[key] == nil { map[key] = ref }
      }
      collectDefinitions(node: child, into: &map)
    }
  }

  private func replaceReferences(
    node: CodeNode<MarkdownNodeElement>, definitions: [String: ReferenceNode]
  ) {
    for (idx, child) in node.children.enumerated() {
      if let refUse = child as? ReferenceNode, refUse.url.isEmpty {
        // Usage: identifier may be empty => derive from text content inside node
        var ident = refUse.identifier
        if ident.isEmpty {
          let text = refUse.children.compactMap { ($0 as? TextNode)?.content }.joined()
          ident = text
        }
        let key = ident.lowercased()
        if let def = definitions[key] {
          let link = LinkNode(url: def.url, title: def.title)
          for grand in refUse.children { link.append(grand) }
          node.children[idx] = link
        }
      }
      replaceReferences(node: child, definitions: definitions)
    }
  }
}

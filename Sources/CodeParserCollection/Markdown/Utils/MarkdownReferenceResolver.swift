import CodeParserCore
import Foundation

enum MarkdownReferenceResolver {
  static func resolve(in root: CodeNode<MarkdownNodeElement>) {
    var definitions: [String: ReferenceNode] = [:]
    collectDefinitions(node: root, into: &definitions)
    replaceReferences(node: root, definitions: definitions)
  }

  private static func collectDefinitions(
    node: CodeNode<MarkdownNodeElement>, into map: inout [String: ReferenceNode]
  ) {
    for child in node.children {
      if let ref = child as? ReferenceNode, !ref.url.isEmpty {
        let key = ref.identifier.lowercased()
        if map[key] == nil { map[key] = ref }
      }
      collectDefinitions(node: child, into: &map)
    }
  }

  private static func replaceReferences(
    node: CodeNode<MarkdownNodeElement>, definitions: [String: ReferenceNode]
  ) {
    for (idx, child) in node.children.enumerated() {
      if let refUse = child as? ReferenceNode, refUse.url.isEmpty {
        var ident = refUse.identifier
        if ident.isEmpty {
          let text = refUse.children.compactMap { ($0 as? TextNode)?.content }.joined()
          ident = text
        }
        let key = ident.lowercased()
        var lookup = definitions[key]
        // Fallback: if explicit identifier not found, try using the text
        // inside the reference node (collapsed reference style).
        if lookup == nil {
          let text = refUse.children.compactMap { ($0 as? TextNode)?.content }.joined()
          lookup = definitions[text.lowercased()]
        }
        if let def = lookup {
          let link = LinkNode(url: def.url, title: def.title)
          for grand in refUse.children { link.append(grand) }
          node.children[idx] = link
          replaceReferences(node: link, definitions: definitions)
          continue
        }
      } else if let img = child as? ImageNode, img.url.isEmpty, !img.title.isEmpty {
        // unresolved reference-style image
        let ident = img.title.lowercased()
        if let def = definitions[ident] {
          img.url = def.url
          img.title = def.title
        }
      }
      replaceReferences(node: child, definitions: definitions)
    }
  }
}

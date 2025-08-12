import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

struct MarkdownTestHarness {
  let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }
}

// Generic AST search helper reused by suites
func findNodes<T: CodeNode<MarkdownNodeElement>>(
  in root: CodeNode<MarkdownNodeElement>, ofType type: T.Type
) -> [T] {
  var result: [T] = []
  func traverse(_ node: CodeNode<MarkdownNodeElement>) {
    if let typed = node as? T { result.append(typed) }
    for child in node.children { traverse(child) }
  }
  traverse(root)
  return result
}

// Shared strict helpers: childrenTypes and sig for unique AST structure checks
func innerText(_ node: CodeNode<MarkdownNodeElement>) -> String {
  findNodes(in: node, ofType: TextNode.self).map { $0.content }.joined()
}

func childrenTypes(_ node: CodeNode<MarkdownNodeElement>) -> [MarkdownNodeElement] {
  node.children.compactMap { ($0 as? MarkdownNodeBase)?.element }
}

func sig(_ node: CodeNode<MarkdownNodeElement>) -> String {
  func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
  }
  func label(_ n: CodeNode<MarkdownNodeElement>) -> String {
    switch n {
    case is DocumentNode: return "document"
    case is ParagraphNode: return "paragraph"
    case let h as HeaderNode: return "heading(level:\(h.level))"
    case is ThematicBreakNode: return "thematic_break"
    case is BlockquoteNode: return "blockquote"
    case let ul as UnorderedListNode:
      return"unordered_list(level:\(ul.level))"
    case let ol as OrderedListNode:
      return "ordered_list(level:\(ol.level))"
    case is ListItemNode: return "list_item"
    case let c as CodeBlockNode: return "code_block(\"\(esc(c.source))\")"
    case let ic as InlineCodeNode: return "code(\"\(esc(ic.code))\")"
    case let t as TextNode: return "text(\"\(esc(t.content))\")"
    case is HTMLNode: return "html"
    case is HTMLBlockNode: return "html_block"
    case let l as LinkNode: return "link(url:\"\(esc(l.url))\",title:\"\(esc(l.title))\")"
    case let i as ImageNode:
      return "image(url:\"\(esc(i.url))\",alt:\"\(esc(i.alt))\",title:\"\(esc(i.title))\")"
    case let br as LineBreakNode: return "line_break(\(br.variant == .hard ? "hard" : "soft"))"
    case is EmphasisNode: return "emphasis"
    case is StrongNode: return "strong"
    case is StrikeNode: return "strike"
    case is TableNode:
      return "table"
    case is TableHeaderNode:
      return "table_header"
    case is TableContentNode:
      return "table_content"
    case is TableRowNode:
      return "table_row"
    case let cell as TableCellNode:
      let a: String
      switch cell.alignment {
      case .none: a = "none"
      case .left: a = "left"
      case .center: a = "center"
      case .right: a = "right"
      }
      return "table_cell(align:\(a))"
    default:
      if let m = n as? MarkdownNodeBase { return m.element.rawValue }
      return "node"
    }
  }
  // Leaf nodes with inline payload already encoded in the label
  if node.children.isEmpty { return label(node) }
  let cs = node.children.map { sig($0) }.joined(separator: ",")
  let head = label(node)
  return "\(head)[\(cs)]"
}

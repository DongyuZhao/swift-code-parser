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
  // Render-like concatenation: text nodes + line breaks
  var parts: [String] = []
  func walk(_ n: CodeNode<MarkdownNodeElement>) {
    if let t = n as? TextNode {
      parts.append(t.content)
    } else if let br = n as? LineBreakNode {
      switch br.variant {
      case .soft:
        parts.append(" ")
      case .hard:
        parts.append("\n")
      }
    }
    for c in n.children { walk(c) }
  }
  walk(node)
  return parts.joined()
}

func childrenTypes(_ node: CodeNode<MarkdownNodeElement>) -> [MarkdownNodeElement] {
  node.children.compactMap { ($0 as? MarkdownNodeBase)?.element }
}

func sig(_ node: CodeNode<MarkdownNodeElement>) -> String {
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
    case let c as CodeBlockNode:
      if let lang = c.language {
        return "code_block(lang:\"\(lang)\",\"\(c.source)\")"
      } else {
        return "code_block(\"\(c.source)\")"
      }
    case let ic as CodeSpanNode: return "code(\"\(ic.code)\")"
    case let t as TextNode: return "text(\"\(t.content)\")"
    case let h as HTMLNode: return "html(\"\(h.content)\")"
    case let hb as HTMLBlockNode: return "html_block(name:\"\(hb.name)\",content:\"\(hb.content)\")"
    case let l as LinkNode: return "link(url:\"\(l.url)\",title:\"\(l.title)\")"
    case let i as ImageNode:
      return "image(url:\"\(i.url)\",alt:\"\(i.alt)\",title:\"\(i.title)\")"
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
    case let r as ReferenceNode:
      return "reference(id:\"\(r.identifier)\",url:\"\(r.url)\",title:\"\(r.title)\")"
    default:
      return n.element.rawValue
    }
  }
  // Leaf nodes with inline payload already encoded in the label
  if node.children.isEmpty { return label(node) }
  let cs = node.children.map { sig($0) }.joined(separator: ",")
  let head = label(node)
  return "\(head)[\(cs)]"
}

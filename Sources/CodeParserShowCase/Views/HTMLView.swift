#if canImport(SwiftUI)
import SwiftUI
import CodeParserCore
import CodeParserCollection

/// A simple HTML preview from Markdown by walking the AST and emitting HTML string.
/// This is a minimal renderer for demo purposes.
struct HTMLView: View {
  let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("HTML")
          .font(.headline)
          .padding(.horizontal)
        Text(htmlString)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .padding(.horizontal)
      }
    }
  }

  private var htmlString: String {
    guard let root = parseResult?.root else { return "" }
    var out = ""
    render(node: root, into: &out)
    return out
  }

  private func render(node: CodeNode<MarkdownNodeElement>, into out: inout String) {
    switch node {
    case is DocumentNode:
      node.children.forEach { render(node: $0, into: &out) }
    case let h as HeaderNode:
      out += "<h\(h.level)>"; node.children.forEach { render(node: $0, into: &out) }; out += "</h\(h.level)>\n"
    case is ParagraphNode:
      out += "<p>"; node.children.forEach { render(node: $0, into: &out) }; out += "</p>\n"
    case is UnorderedListNode:
      out += "<ul>\n"; node.children.forEach { render(node: $0, into: &out) }; out += "</ul>\n"
    case is OrderedListNode:
      out += "<ol>\n"; node.children.forEach { render(node: $0, into: &out) }; out += "</ol>\n"
    case is ListItemNode:
      out += "<li>"; node.children.forEach { render(node: $0, into: &out) }; out += "</li>\n"
    case let t as TextNode:
      out += escapeHTML(t.content)
    case let s as StrongNode:
      out += "<strong>"; s.children.forEach { render(node: $0, into: &out) }; out += "</strong>"
    case is EmphasisNode:
      out += "<em>"; node.children.forEach { render(node: $0, into: &out) }; out += "</em>"
    case let c as InlineCodeNode:
      out += "<code>\(escapeHTML(c.code))</code>"
    case let code as CodeBlockNode:
      out += "<pre><code class=\"language-\(code.language ?? "")\">\(escapeHTML(code.source))</code></pre>\n"
    default:
      // Fallback: render children inline
      node.children.forEach { render(node: $0, into: &out) }
    }
  }

  private func escapeHTML(_ s: String) -> String {
    s
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
#endif

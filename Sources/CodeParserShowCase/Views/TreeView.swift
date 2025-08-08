#if canImport(SwiftUI)
import SwiftUI
import CodeParserCore
import CodeParserCollection

struct TreeView: View {
  let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Parse Tree")
        .font(.headline)
        .padding(.horizontal)

      if let result = parseResult {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            NodeTreeView(node: result.root, level: 0)
          }
          .padding(.horizontal)
        }
      } else {
        Text("No parsing results")
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }
    }
  }
}

#endif

struct NodeTreeView: View {
  let node: CodeNode<MarkdownNodeElement>
  let level: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(String(repeating: "  ", count: level) + "├─")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)

        Text(node.element.rawValue)
          .font(.caption)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.green.opacity(0.2))
          .cornerRadius(4)

        if let textNode = node as? TextNode {
          Text("\"\(textNode.content)\"")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
        } else if let headerNode = node as? HeaderNode {
          Text("level: \(headerNode.level)")
            .font(.caption)
            .foregroundColor(.secondary)
        } else if let codeNode = node as? CodeBlockNode {
          Text("lang: \(codeNode.language ?? "none")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()
      }

      ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
        NodeTreeView(node: child, level: level + 1)
      }
    }
  }
}

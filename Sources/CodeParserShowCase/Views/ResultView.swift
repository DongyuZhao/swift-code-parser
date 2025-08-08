#if canImport(SwiftUI)
import SwiftUI
import CodeParserCore
import CodeParserCollection

struct ResultView: View {
  let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
  @State private var selectedNode: CodeNode<MarkdownNodeElement>?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Interactive AST Explorer")
        .font(.headline)
        .padding(.horizontal)

      if let result = parseResult {
  ResizableSplitView(minLeading: 220, minTrailing: 240, initialProportion: 0.45, handleWidth: 5,
          leading: {
          // Tree view
          ScrollView {
            VStack(alignment: .leading, spacing: 2) {
              InteractiveNodeView(
                node: result.root,
                level: 0,
                selectedNode: $selectedNode
              )
            }
            .padding(.horizontal)
          }
          .frame(minWidth: 200)
          },
          trailing: {
            // Details view
            VStack(alignment: .leading, spacing: 8) {
              if let selected = selectedNode {
                NodeDetailsView(node: selected)
              } else {
                Text("Select a node to view details")
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
            }
            .padding()
            .background(detailsBackground)
          }
        )
      } else {
        Text("No parsing results")
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }
    }
  }

  private var detailsBackground: Color {
    #if os(macOS)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color(UIColor.secondarySystemBackground)
    #endif
  }
}

#endif

struct InteractiveNodeView: View {
  let node: CodeNode<MarkdownNodeElement>
  let level: Int
  @Binding var selectedNode: CodeNode<MarkdownNodeElement>?
  @State private var isExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        if !node.children.isEmpty {
          Button(action: {
            isExpanded.toggle()
          }) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
          }
          .buttonStyle(.plain)
        } else {
          Text("  ")
            .font(.caption)
        }

        Text(String(repeating: "  ", count: level))
          .font(.system(.caption, design: .monospaced))

        Button(action: {
          selectedNode = node
        }) {
          Text(node.element.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(selectedNode === node ? Color.blue.opacity(0.3) : Color.green.opacity(0.2))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)

        Spacer()
      }

      if isExpanded {
        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
          InteractiveNodeView(
            node: child,
            level: level + 1,
            selectedNode: $selectedNode
          )
        }
      }
    }
  }
}

struct NodeDetailsView: View {
  let node: CodeNode<MarkdownNodeElement>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Node Details")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        DetailRow(label: "Type", value: node.element.rawValue)
        DetailRow(label: "Children", value: "\(node.children.count)")

        if let textNode = node as? TextNode {
          DetailRow(label: "Content", value: textNode.content)
        }

        if let headerNode = node as? HeaderNode {
          DetailRow(label: "Level", value: "\(headerNode.level)")
        }

        if let codeNode = node as? CodeBlockNode {
          DetailRow(label: "Language", value: codeNode.language ?? "none")
          DetailRow(label: "Source", value: codeNode.source)
        }

        if let linkNode = node as? LinkNode {
          DetailRow(label: "URL", value: linkNode.url)
          DetailRow(label: "Title", value: linkNode.title.isEmpty ? "none" : linkNode.title)
        }

        if let imageNode = node as? ImageNode {
          DetailRow(label: "URL", value: imageNode.url)
          DetailRow(label: "Alt Text", value: imageNode.alt)
        }
      }

      Spacer()
    }
  }
}

struct DetailRow: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
  }
}

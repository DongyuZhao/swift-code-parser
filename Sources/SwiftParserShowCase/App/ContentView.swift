#if canImport(SwiftUI) && !os(Linux)
import SwiftUI
import SwiftParser

struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var astText: String = ""
    @State private var htmlText: String = ""
    @State private var rootNode: MarkdownNodeBase?

    var body: some View {
        VStack {
            TextEditor(text: $markdownText)
                .border(Color.gray)
                .frame(minHeight: 200)
                .onChange(of: markdownText) { _ in
                    updateOutputs()
                }
                .onAppear {
                    updateOutputs()
                }

            TabView {
                ScrollView {
                    Text(astText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .tabItem { Text("Print AST") }

                ScrollView {
                    Text(htmlText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .tabItem { Text("Export HTML") }

                ScrollView {
                    if let rootNode {
                        MarkdownView(root: rootNode)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .tabItem { Text("Render View") }
            }
        }
        .padding()
    }

    private func updateOutputs() {
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdownText, language: language)
        astText = ASTPrinter.print(node: result.root)
        htmlText = HTMLExporter.export(node: result.root)
        rootNode = result.root as? MarkdownNodeBase
    }
}

// MARK: - Markdown Rendering
@ViewBuilder
private func MarkdownView(root: MarkdownNodeBase) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        renderChildren(root.children())
    }
}

@ViewBuilder
private func renderChildren(_ nodes: [MarkdownNodeBase]) -> some View {
    ForEach(nodes, id: \.id) { node in
        render(node)
    }
}

@ViewBuilder
private func render(_ node: MarkdownNodeBase) -> some View {
    switch node {
    case let paragraph as ParagraphNode:
        makeText(paragraph.children())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    case let header as HeaderNode:
        makeText(header.children())
            .font(.system(size: fontSize(for: header.level), weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    case let code as CodeBlockNode:
        ScrollView(.horizontal) {
            Text(code.source)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
        .background(Color(.systemGray6))
        .cornerRadius(4)
        .padding(.bottom, 4)
    case let blockquote as BlockquoteNode:
        VStack(alignment: .leading, spacing: 4) {
            renderChildren(blockquote.children())
        }
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: 3)
                .foregroundColor(Color.gray.opacity(0.6))
        }
        .padding(.bottom, 4)
    case let list as OrderedListNode:
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.children().enumerated()), id: \.element.id) { idx, item in
                if let li = item as? ListItemNode {
                    HStack(alignment: .top) {
                        Text("\(list.start + idx).")
                        VStack(alignment: .leading, spacing: 4) {
                            renderChildren(li.children())
                        }
                    }
                } else {
                    render(item)
                }
            }
        }
        .padding(.bottom, 4)
    case let list as UnorderedListNode:
        VStack(alignment: .leading, spacing: 4) {
            ForEach(list.children(), id: \.id) { item in
                if let li = item as? ListItemNode {
                    HStack(alignment: .top) {
                        Text("\u{2022}")
                        VStack(alignment: .leading, spacing: 4) {
                            renderChildren(li.children())
                        }
                    }
                } else {
                    render(item)
                }
            }
        }
        .padding(.bottom, 4)
    case let image as ImageNode:
        if let url = URL(string: image.url) {
            if #available(iOS 15.0, macOS 12.0, *) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        Text(image.alt)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        Text(image.alt)
                    }
                }
            } else {
                Text(image.alt)
            }
        } else {
            Text(image.alt)
        }
        .padding(.bottom, 4)
    default:
        renderChildren(node.children())
    }
}

private func fontSize(for level: Int) -> CGFloat {
    switch level {
    case 1: return 28
    case 2: return 24
    case 3: return 20
    case 4: return 18
    case 5: return 16
    default: return 14
    }
}

private func makeText(_ nodes: [MarkdownNodeBase]) -> Text {
    nodes.reduce(Text("")) { result, node in
        result + makeText(node)
    }
}

private func makeText(_ node: MarkdownNodeBase) -> Text {
    switch node {
    case let text as TextNode:
        return Text(text.content)
    case let strong as StrongNode:
        return makeText(strong.children()).bold()
    case let emphasis as EmphasisNode:
        return makeText(emphasis.children()).italic()
    case let strike as StrikeNode:
        return makeText(strike.children()).strikethrough()
    case let code as InlineCodeNode:
        return Text(code.code)
            .font(.system(.body, design: .monospaced))
            .background(Color(.systemGray5))
    case let link as LinkNode:
        return makeText(link.children())
            .foregroundColor(.blue)
    case is LineBreakNode:
        return Text("\n")
    default:
        return node.children().reduce(Text("")) { result, child in
            result + makeText(child)
        }
    }
}

#endif

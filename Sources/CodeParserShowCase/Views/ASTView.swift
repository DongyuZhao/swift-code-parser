import SwiftUI

struct ASTView: View {
    let language: LanguageOption
    let inputText: String
    
    @State private var astNodes: [ASTNode] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Abstract Syntax Tree")
                .font(.headline)
                .padding(.horizontal)
            
            if astNodes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tree")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No AST yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Parse your input to see the syntax tree")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(astNodes) { node in
                            ASTNodeView(node: node, level: 0)
                        }
                    }
                    .padding()
                }
            }
        }
        .padding(.vertical)
        .navigationTitle("AST")
        .onAppear {
            generateMockAST()
        }
        .onChange(of: inputText) { _ in
            generateMockAST()
        }
    }
    
    private func generateMockAST() {
        // TODO: Replace with actual AST generation
        astNodes = [
            ASTNode(
                type: "Document",
                value: nil,
                children: [
                    ASTNode(type: "Heading", value: "Hello CodeParser!", children: []),
                    ASTNode(
                        type: "Paragraph",
                        value: nil,
                        children: [
                            ASTNode(type: "Text", value: "This is a ", children: []),
                            ASTNode(type: "Strong", value: "demo", children: []),
                            ASTNode(type: "Text", value: " of the CodeParser framework.", children: [])
                        ]
                    ),
                    ASTNode(
                        type: "List",
                        value: nil,
                        children: [
                            ASTNode(type: "ListItem", value: "Feature 1: Markdown parsing", children: []),
                            ASTNode(type: "ListItem", value: "Feature 2: Token analysis", children: []),
                            ASTNode(type: "ListItem", value: "Feature 3: AST construction", children: [])
                        ]
                    )
                ]
            )
        ]
    }
}

struct ASTNodeView: View {
    let node: ASTNode
    let level: Int
    
    @State private var isExpanded: Bool = true
    
    private var indentationPadding: CGFloat {
        CGFloat(level * 20)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    if !node.children.isEmpty {
                        Button(action: { isExpanded.toggle() }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 16)
                    }
                    
                    Text(node.type)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if let value = node.value {
                        Text(":")
                            .foregroundStyle(.secondary)
                        Text("\"\(value)\"")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.leading, indentationPadding)
            
            if isExpanded {
                ForEach(node.children) { child in
                    ASTNodeView(node: child, level: level + 1)
                }
            }
        }
    }
}

struct ASTNode: Identifiable {
    let id = UUID()
    let type: String
    let value: String?
    let children: [ASTNode]
}

#Preview {
    ASTView(language: .markdown, inputText: "# Hello World")
}

import SwiftUI

struct TokensView: View {
    let language: LanguageOption
    let inputText: String
    
    @State private var tokens: [TokenInfo] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tokens")
                .font(.headline)
                .padding(.horizontal)
            
            if tokens.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No tokens yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Parse your input to see token analysis")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tokens) { token in
                    TokenRow(token: token)
                }
                .listStyle(.plain)
            }
        }
        .padding(.vertical)
        .navigationTitle("Tokens")
        .onAppear {
            generateMockTokens()
        }
        .onChange(of: inputText) { _ in
            generateMockTokens()
        }
    }
    
    private func generateMockTokens() {
        // TODO: Replace with actual tokenization
        tokens = [
            TokenInfo(type: "Heading", value: "# Hello CodeParser!", range: "0-18"),
            TokenInfo(type: "Text", value: "This is a", range: "20-30"),
            TokenInfo(type: "Strong", value: "**demo**", range: "31-39"),
            TokenInfo(type: "Text", value: "of the CodeParser framework.", range: "40-69"),
            TokenInfo(type: "ListItem", value: "- Feature 1:", range: "71-83"),
            TokenInfo(type: "Text", value: "Markdown parsing", range: "84-100"),
        ]
    }
}

struct TokenRow: View {
    let token: TokenInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(token.type)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(token.value)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3)
            }
            
            Spacer()
            
            Text(token.range)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct TokenInfo: Identifiable {
    let id = UUID()
    let type: String
    let value: String
    let range: String
}

#Preview {
    TokensView(language: .markdown, inputText: "# Hello World")
}

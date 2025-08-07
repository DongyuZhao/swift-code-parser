import SwiftUI

struct ResultView: View {
    let result: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parse Result")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Parsing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if result.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No results yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Click the Parse button to analyze your input")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #if os(iOS)
                        .background(Color(UIColor.systemGray6))
                        #else
                        .background(Color(NSColor.controlBackgroundColor))
                        #endif
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .navigationTitle("Result")
    }
}

#Preview {
    ResultView(result: "Sample parsing result", isLoading: false)
}

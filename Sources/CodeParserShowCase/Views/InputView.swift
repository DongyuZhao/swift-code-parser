import SwiftUI

struct InputView: View {
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Text")
                .font(.headline)
                .padding(.horizontal)
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                #if os(iOS)
                .background(Color(UIColor.systemGray6))
                #else
                .background(Color(NSColor.controlBackgroundColor))
                #endif
                .cornerRadius(8)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle("Input")
    }
}

#Preview {
    InputView(text: .constant("# Hello World\n\nThis is a test."))
}

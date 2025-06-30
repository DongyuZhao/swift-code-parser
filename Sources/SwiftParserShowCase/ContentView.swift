import SwiftUI
import SwiftParser

struct ContentView: View {
    @State private var sourceCode: String = """
    import Foundation
    
    struct Example {
        let name: String
        
        func greet() {
            print("Hello, \\(name)!")
        }
    }
    """
    
    @State private var parsedResult: String = ""
    private let parser = SwiftParser()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SwiftParser ShowCase")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Swift Source Code:")
                        .font(.headline)
                    
                    TextEditor(text: $sourceCode)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
                }
                
                Button("Parse Code") {
                    let result = parser.parse(sourceCode)
                    parsedResult = "Parsed content: \\(result.content.count) characters"
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                if !parsedResult.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Parse Result:")
                            .font(.headline)
                        
                        Text(parsedResult)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI
import SwiftParser

struct ContentView: View {
    enum DemoLanguage: String, CaseIterable, Identifiable {
        case python
        case markdown
        var id: String { rawValue }

        var language: CodeLanguage {
            switch self {
            case .python: return PythonLanguage()
            case .markdown: return MarkdownLanguage()
            }
        }
    }

    @State private var language: DemoLanguage = .python
    @State private var sourceCode: String = """
print("Hello")
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

                Picker("Language", selection: $language) {
                    ForEach(DemoLanguage.allCases) { lang in
                        Text(lang.rawValue.capitalized).tag(lang)
                    }
                }.pickerStyle(.segmented)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Source Code:")
                        .font(.headline)

                    TextEditor(text: $sourceCode)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
                }

                Button("Parse Code") {
                    let result = parser.parse(sourceCode, language: language.language)
                    parsedResult = "Errors: \(result.errors.count), children: \(result.root.children.count)"
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

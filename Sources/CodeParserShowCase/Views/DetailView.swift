import SwiftUI
import CodeParser

struct DetailView: View {
    @Binding var inputText: String
    @Binding var selectedLanguage: LanguageOption
    @Binding var parseResult: String
    @Binding var isParsingInProgress: Bool
    
    @State private var selectedTab: DetailTab = .input
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                selectedLanguage: selectedLanguage,
                onParseAction: parseContent
            )
            
            // Tab View
            TabView(selection: $selectedTab) {
                InputView(text: $inputText)
                    .tabItem {
                        Label("Input", systemImage: "doc.text")
                    }
                    .tag(DetailTab.input)
                
                ResultView(
                    result: parseResult,
                    isLoading: isParsingInProgress
                )
                .tabItem {
                    Label("Result", systemImage: "doc.text.fill")
                }
                .tag(DetailTab.result)
                
                TokensView(
                    language: selectedLanguage,
                    inputText: inputText
                )
                .tabItem {
                    Label("Tokens", systemImage: "list.bullet")
                }
                .tag(DetailTab.tokens)
                
                ASTView(
                    language: selectedLanguage,
                    inputText: inputText
                )
                .tabItem {
                    Label("AST", systemImage: "tree")
                }
                .tag(DetailTab.ast)
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
    
    private func parseContent() {
        isParsingInProgress = true
        
        Task {
            do {
                let result = try await parseWithLanguage(selectedLanguage, text: inputText)
                await MainActor.run {
                    parseResult = result
                    selectedTab = .result
                    isParsingInProgress = false
                }
            } catch {
                await MainActor.run {
                    parseResult = "Error: \(error.localizedDescription)"
                    selectedTab = .result
                    isParsingInProgress = false
                }
            }
        }
    }
}

private func parseWithLanguage(_ language: LanguageOption, text: String) async throws -> String {
    // TODO: Implement actual parsing logic
    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay to simulate processing
    
    switch language {
    case .markdown:
        return """
        # Parsed Markdown Structure
        
        ## Document Root
        - Heading (Level 1): "Hello CodeParser!"
        - Paragraph: "This is a **demo** of the CodeParser framework."
        - List (Unordered):
          - Item 1: "Feature 1: Markdown parsing"
          - Item 2: "Feature 2: Token analysis"
          - Item 3: "Feature 3: AST construction"
        - Code Block (Swift):
          ```
          let parser = CodeParser()
          parser.parse(source)
          ```
        - Blockquote: "This is just the beginning! More features coming soon."
        
        ## Statistics
        - Total tokens: 45
        - Paragraphs: 2
        - Code blocks: 1
        - Lists: 1
        """
    case .swift:
        return "Swift parsing not yet implemented"
    case .json:
        return "JSON parsing not yet implemented"
    case .xml:
        return "XML parsing not yet implemented"
    }
}

#Preview {
    NavigationView {
        DetailView(
            inputText: .constant("# Hello World"),
            selectedLanguage: .constant(.markdown),
            parseResult: .constant("Sample result"),
            isParsingInProgress: .constant(false)
        )
    }
}

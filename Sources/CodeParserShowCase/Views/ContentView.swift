import SwiftUI
import CodeParser

struct ContentView: View {
    @State private var inputText: String = """
# Hello CodeParser!

This is a **demo** of the CodeParser framework.

- Feature 1: Markdown parsing
- Feature 2: Token analysis  
- Feature 3: AST construction

```swift
let parser = CodeParser()
parser.parse(source)
```

> This is just the beginning! More features coming soon.
"""
    
    @State private var selectedLanguage: LanguageOption = .markdown
    @State private var parseResult: String = ""
    @State private var isParsingInProgress: Bool = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedLanguage: $selectedLanguage)
        } detail: {
            DetailView(
                inputText: $inputText,
                selectedLanguage: $selectedLanguage,
                parseResult: $parseResult,
                isParsingInProgress: $isParsingInProgress
            )
        }
        .navigationTitle("CodeParser ShowCase")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

#Preview {
    ContentView()
}

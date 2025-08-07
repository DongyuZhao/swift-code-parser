#if canImport(SwiftUI)
  import SwiftUI
  import CodeParserCore
  import CodeParserCollection

  @main
  struct CodeParserShowCaseApp: App {
    var body: some Scene {
      WindowGroup {
        ContentView()
      }
      .windowResizability(.contentSize)
    }
  }

  struct ContentView: View {
    @State private var inputText = """
    # Sample Markdown
    
    This is a **bold** text with some *emphasis*.
    
    ```swift
    let greeting = "Hello, World!"
    print(greeting)
    ```
    
    - Item 1
    - Item 2
      - Nested item
    
    | Column 1 | Column 2 |
    |----------|----------|
    | Cell 1   | Cell 2   |
    """
    
    @State private var selectedTab = 0
    @State private var parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
    
    private let language = MarkdownLanguage()
    private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
    
    init() {
      parser = CodeParser(language: language)
    }
    
    var body: some View {
      HSplitView {
        // Input Section
        VStack(alignment: .leading, spacing: 8) {
          Text("Code Input")
            .font(.headline)
            .padding(.horizontal)
          
          TextEditor(text: $inputText)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
          
          Button("Parse Code") {
            parseCode()
          }
          .padding(.horizontal)
          .buttonStyle(.borderedProminent)
        }
        .frame(minWidth: 300)
        
        // Output Section
        VStack(alignment: .leading, spacing: 0) {
          // Tab selection
          Picker("View", selection: $selectedTab) {
            Text("Tokens").tag(0)
            Text("Parse Tree").tag(1)
            Text("Interactive AST").tag(2)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal)
          
          // Tab content
          Group {
            switch selectedTab {
            case 0:
              TokenView(parseResult: parseResult)
            case 1:
              ParseTreeView(parseResult: parseResult)
            default:
              InteractiveASTView(parseResult: parseResult)
            }
          }
        }
        .frame(minWidth: 400)
      }
      .onAppear {
        parseCode()
      }
    }
    
    private func parseCode() {
      parseResult = parser.parse(inputText, language: language)
    }
  }

  // MARK: - Token View
  struct TokenView: View {
    let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
    
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Tokenization Results")
          .font(.headline)
          .padding(.horizontal)
        
        if let result = parseResult {
          if !result.errors.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Errors:")
                .font(.subheadline)
                .foregroundColor(.red)
              ForEach(Array(result.errors.enumerated()), id: \.offset) { _, error in
                Text("• \(error.message)")
                  .font(.caption)
                  .foregroundColor(.red)
              }
            }
            .padding(.horizontal)
          }
          
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
              ForEach(Array(result.tokens.enumerated()), id: \.offset) { index, token in
                TokenRowView(index: index, token: token)
              }
            }
            .padding(.horizontal)
          }
        } else {
          Text("No parsing results")
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
      }
    }
  }

  struct TokenRowView: View {
    let index: Int
    let token: any CodeToken<MarkdownTokenElement>
    
    var body: some View {
      HStack(alignment: .top, spacing: 8) {
        Text("\(index)")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 30, alignment: .trailing)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(token.element.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(4)
          
          if !token.text.isEmpty {
            Text(token.text.replacingOccurrences(of: "\n", with: "\\n"))
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.secondary)
          }
        }
        
        Spacer()
      }
      .padding(.vertical, 2)
    }
  }

  // MARK: - Parse Tree View
  struct ParseTreeView: View {
    let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
    
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Parse Tree")
          .font(.headline)
          .padding(.horizontal)
        
        if let result = parseResult {
          ScrollView {
            VStack(alignment: .leading, spacing: 4) {
              NodeTreeView(node: result.root, level: 0)
            }
            .padding(.horizontal)
          }
        } else {
          Text("No parsing results")
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
      }
    }
  }

  struct NodeTreeView: View {
    let node: CodeNode<MarkdownNodeElement>
    let level: Int
    
    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(String(repeating: "  ", count: level) + "├─")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
          
          Text(node.element.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.2))
            .cornerRadius(4)
          
          if let textNode = node as? TextNode {
            Text("\"\(textNode.content)\"")
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.secondary)
          } else if let headerNode = node as? HeaderNode {
            Text("level: \(headerNode.level)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else if let codeNode = node as? CodeBlockNode {
            Text("lang: \(codeNode.language ?? "none")")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          Spacer()
        }
        
        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
          NodeTreeView(node: child, level: level + 1)
        }
      }
    }
  }

  // MARK: - Interactive AST View
  struct InteractiveASTView: View {
    let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
    @State private var selectedNode: CodeNode<MarkdownNodeElement>?
    
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Interactive AST Explorer")
          .font(.headline)
          .padding(.horizontal)
        
        if let result = parseResult {
          HSplitView {
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
            .background(Color(NSColor.controlBackgroundColor))
          }
        } else {
          Text("No parsing results")
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
      }
    }
  }

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

#else
  import CodeParserCore
  import CodeParserCollection
  import Foundation

  @main
  struct CodeParserShowCase {
    static func main() {
      print("🚀 CodeParser Console Interface")
      print("================================")
      
      let language = MarkdownLanguage()
      let parser = CodeParser(language: language)
      
      // Interactive console mode
      while true {
        print("\nOptions:")
        print("1. Parse sample Markdown")
        print("2. Enter custom input")
        print("3. Exit")
        print("Choose an option (1-3): ", terminator: "")
        
        guard let input = readLine(), let choice = Int(input) else {
          print("Invalid input. Please enter 1, 2, or 3.")
          continue
        }
        
        switch choice {
        case 1:
          parseSampleMarkdown(parser: parser, language: language)
        case 2:
          parseCustomInput(parser: parser, language: language)
        case 3:
          print("Goodbye!")
          return
        default:
          print("Invalid option. Please choose 1, 2, or 3.")
        }
      }
    }
    
    static func parseSampleMarkdown(
      parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>,
      language: MarkdownLanguage
    ) {
      let sampleMarkdown = """
      # Sample Markdown Document
      
      This is a **bold** text with some *emphasis*.
      
      ```swift
      let greeting = "Hello, World!"
      print(greeting)
      ```
      
      ## List Example
      - Item 1
      - Item 2
        - Nested item
      
      ## Table Example
      | Column 1 | Column 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      """
      
      print("\n📝 Parsing Sample Markdown:")
      print("=" * 50)
      print(sampleMarkdown)
      print("=" * 50)
      
      parseAndDisplay(input: sampleMarkdown, parser: parser, language: language)
    }
    
    static func parseCustomInput(
      parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>,
      language: MarkdownLanguage
    ) {
      print("\n📝 Enter your Markdown (press Enter twice when finished):")
      var lines: [String] = []
      var emptyLineCount = 0
      
      while true {
        if let line = readLine() {
          if line.isEmpty {
            emptyLineCount += 1
            if emptyLineCount >= 2 {
              break
            }
          } else {
            emptyLineCount = 0
          }
          lines.append(line)
        }
      }
      
      let input = lines.joined(separator: "\n")
      if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parseAndDisplay(input: input, parser: parser, language: language)
      } else {
        print("No input provided.")
      }
    }
    
    static func parseAndDisplay(
      input: String,
      parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>,
      language: MarkdownLanguage
    ) {
      let result = parser.parse(input, language: language)
      
      print("\n🔍 Results:")
      print("-" * 50)
      
      // Display errors if any
      if !result.errors.isEmpty {
        print("❌ Errors:")
        for error in result.errors {
          print("  • \(error.message)")
        }
        print()
      }
      
      // Display options
      while true {
        print("What would you like to view?")
        print("1. Tokens")
        print("2. Parse Tree")
        print("3. Node Statistics")
        print("4. Back to main menu")
        print("Choose an option (1-4): ", terminator: "")
        
        guard let input = readLine(), let choice = Int(input) else {
          print("Invalid input. Please enter 1, 2, 3, or 4.")
          continue
        }
        
        switch choice {
        case 1:
          displayTokens(result.tokens)
        case 2:
          displayParseTree(result.root)
        case 3:
          displayNodeStatistics(result.root)
        case 4:
          return
        default:
          print("Invalid option. Please choose 1, 2, 3, or 4.")
        }
      }
    }
    
    static func displayTokens(_ tokens: [any CodeToken<MarkdownTokenElement>]) {
      print("\n🎯 Tokens (\(tokens.count) total):")
      print("-" * 30)
      
      for (index, token) in tokens.enumerated() {
        let text = token.text.replacingOccurrences(of: "\n", with: "\\n")
        let truncatedText = text.count > 20 ? String(text.prefix(20)) + "..." : text
        print(String(format: "%3d: %-15s '%s'", index, token.element.rawValue, truncatedText))
      }
    }
    
    static func displayParseTree(_ root: CodeNode<MarkdownNodeElement>) {
      print("\n🌳 Parse Tree:")
      print("-" * 30)
      displayNode(root, level: 0)
    }
    
    static func displayNode(_ node: CodeNode<MarkdownNodeElement>, level: Int) {
      let indent = String(repeating: "  ", count: level)
      let prefix = level == 0 ? "" : "├─ "
      
      var nodeInfo = "\(indent)\(prefix)\(node.element.rawValue)"
      
      // Add specific node information
      if let textNode = node as? TextNode {
        let content = textNode.content.replacingOccurrences(of: "\n", with: "\\n")
        let truncated = content.count > 30 ? String(content.prefix(30)) + "..." : content
        nodeInfo += " (\"\(truncated)\")"
      } else if let headerNode = node as? HeaderNode {
        nodeInfo += " (level: \(headerNode.level))"
      } else if let codeNode = node as? CodeBlockNode {
        nodeInfo += " (lang: \(codeNode.language ?? "none"))"
      } else if let linkNode = node as? LinkNode {
        nodeInfo += " (url: \(linkNode.url))"
      }
      
      print(nodeInfo)
      
      for child in node.children {
        displayNode(child, level: level + 1)
      }
    }
    
    static func displayNodeStatistics(_ root: CodeNode<MarkdownNodeElement>) {
      print("\n📊 Node Statistics:")
      print("-" * 30)
      
      var counts: [MarkdownNodeElement: Int] = [:]
      var totalNodes = 0
      
      func countNodes(_ node: CodeNode<MarkdownNodeElement>) {
        counts[node.element, default: 0] += 1
        totalNodes += 1
        for child in node.children {
          countNodes(child)
        }
      }
      
      countNodes(root)
      
      print("Total nodes: \(totalNodes)")
      print()
      
      for (element, count) in counts.sorted(by: { $0.value > $1.value }) {
        print(String(format: "%-20s: %d", element.rawValue, count))
      }
    }
  }

  extension String {
    static func *(lhs: String, rhs: Int) -> String {
      return String(repeating: lhs, count: rhs)
    }
  }
#endif

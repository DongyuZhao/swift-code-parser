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
  print("3. Launch TUI editor (^Q to quit)")
  print("4. Exit")
  print("Choose an option (1-4): ", terminator: "")

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
          launchTUIEditor()
        case 4:
          print("Goodbye!")
          return
        default:
          print("Invalid option. Please choose 1, 2, 3, or 4.")
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

    static func launchTUIEditor() {
      #if !canImport(SwiftUI)
      let editor = TUIEditor()
      editor.run()
      #else
      print("TUI editor is only available in console builds.")
      #endif
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

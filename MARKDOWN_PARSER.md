# Markdown Parser

This document provides an overview of the Markdown parser built on top of the SwiftParser core. The parser follows the CommonMark specification and supports various consumers to generate different node types while handling prefix ambiguities.

## Features

### CommonMark Support
- ✅ ATX headers (# Heading)
- ✅ Paragraphs
- ✅ Emphasis (*italic*, **bold**) with nested structures and backtracking
- ✅ Inline code (`code`)
- ✅ Fenced code blocks (```code```)
- ✅ Block quotes (> quote) with multi-line merging
- ✅ Lists (ordered and unordered) with automatic numbering
- ✅ Links ([text](URL) and reference style)
- ✅ Images (![alt](URL))
- ✅ Autolinks (<URL>)
- ✅ Horizontal rules (---)
- ✅ HTML inline elements
- ✅ HTML block elements
- ✅ Line break handling

### GitHub Flavored Markdown (GFM) Extensions
- ✅ Tables
- ✅ Strikethrough (~~text~~)
- ✅ Task lists (- [ ], - [x])

### Academic Extensions
- ✅ **Footnotes**: Definition and reference support ([^1]: footnote, [^1])
- ✅ **Citations**: Academic citation support ([@author2023]: reference, [@author2023])
- ✅ **Math formulas**: inline ($math$) and block ($$math$$)

### Advanced List Features
- ✅ **Unordered lists**: supports `-`, `*`, `+` markers
- ✅ **Ordered lists**: automatic numbering (1. 1. 1. → 1. 2. 3.)
- ✅ **Task lists**: GitHub-style checkboxes (- [ ] and - [x])
- ✅ **Item grouping**: correctly groups items under the same list container
- ✅ **Smart marker detection**: distinguishes list markers from emphasis markers

### Advanced Capabilities
- ✅ Partial node handling for prefix ambiguities
- ✅ Multi-consumer architecture
- ✅ Configurable consumer combinations
- ✅ Error handling and reporting
- ✅ AST traversal and queries
- ✅ Backtracking reorganization for emphasis parsing
- ✅ Global AST rebuilding for complex nesting
- ✅ Best-match strategy favoring strong emphasis
- ✅ Container reuse logic for optimized AST structure

## Basic Usage

### Simple Parsing

```swift
import SwiftParser

let parser = SwiftParser()
let markdown = """
# Heading

This is a paragraph with **bold** and *italic* text.

```swift
let code = "Hello, World!"
```

- Item 1
- Item 2

1. Ordered item 1
1. Ordered item 2
1. Ordered item 3

- [ ] Incomplete task
- [x] Completed task

> Block quote
> Spans multiple lines

This paragraph contains a footnote[^1] and a citation[@smith2023].

[^1]: This is a footnote definition.
[@smith2023]: Smith, J. (2023). Example Paper. Journal of Examples.
"""

let result = parser.parseMarkdown(markdown)

// Inspect the result
if result.hasErrors {
    print("Parse errors:")
    for error in result.errors {
        print("- \(error)")
    }
} else {
    print("Parse succeeded with \(result.root.children.count) top-level nodes")
}
```

### Finding Specific Elements

```swift
// Find all headers
let headers = result.markdownNodes(ofType: .header1) +
              result.markdownNodes(ofType: .header2) +
              result.markdownNodes(ofType: .header3) +
              result.markdownNodes(ofType: .header4) +
              result.markdownNodes(ofType: .header5) +
              result.markdownNodes(ofType: .header6)

for header in headers {
    print("Header: \(header.value)")
}

// Find all links
let links = result.markdownNodes(ofType: .link)
for link in links {
    print("Link text: \(link.value)")
    if let url = link.children.first?.value {
        print("URL: \(url)")
    }
}

// Find all code blocks
let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
for codeBlock in codeBlocks {
    if let language = codeBlock.children.first?.value {
        print("Language: \(language)")
    }
    print("Code: \(codeBlock.value)")
}

// Find lists
let unorderedLists = result.markdownNodes(ofType: .unorderedList)
let orderedLists = result.markdownNodes(ofType: .orderedList)
let taskLists = result.markdownNodes(ofType: .taskList)

print("Unordered lists: \(unorderedLists.count)")
print("Ordered lists: \(orderedLists.count)")
print("Task lists: \(taskLists.count)")

// Find footnotes and citations
let footnoteDefinitions = result.markdownNodes(ofType: .footnoteDefinition)
let footnoteReferences = result.markdownNodes(ofType: .footnoteReference)
let citationDefinitions = result.markdownNodes(ofType: .citation)
let citationReferences = result.markdownNodes(ofType: .citationReference)

print("Footnote definitions: \(footnoteDefinitions.count)")
print("Footnote references: \(footnoteReferences.count)")
print("Citation definitions: \(citationDefinitions.count)")
print("Citation references: \(citationReferences.count)")

// Process footnotes
for footnote in footnoteDefinitions {
    print("Footnote ID: \(footnote.value)")
    if let content = footnote.children.first?.value {
        print("Content: \(content)")
    }
}

// Process citations
for citation in citationDefinitions {
    print("Citation ID: \(citation.value)")
    if let content = citation.children.first?.value {
        print("Content: \(content)")
    }
}
```

### Traversing the AST

```swift
// Depth-first traversal
result.root.traverseDepthFirst { node in
    if let mdElement = node.type as? MarkdownElement {
        print("Type: \(mdElement.description), value: \(node.value)")
    }
}

// Breadth-first traversal
result.root.traverseBreadthFirst { node in
    // Handle each node
}

// Find a specific node
let firstParagraph = result.root.first { node in
    (node.type as? MarkdownElement) == .paragraph
}

// Find all list items
let allListItems = result.root.findAll { node in
    let element = node.type as? MarkdownElement
    return element == .listItem || element == .taskListItem
}
```

## Advanced Usage

### Using Core Parser with Custom Configuration

```swift
import SwiftParser

// Create a custom language with specific consumer combinations
let language = MarkdownLanguage()
let parser = CodeParser(language: language)

// Create a root node for the document
let rootNode = CodeNode(type: MarkdownElement.document, value: "")

// Parse with custom configuration
let result = parser.parse(markdown, rootNode: rootNode)

// Access the parsed tree
let parsedTree = result.node
let errors = result.context.errors

// Check for parse errors
if !errors.isEmpty {
    print("Parse errors occurred:")
    for error in errors {
        print("- \(error.message) at line \(error.line)")
    }
}
```

### Working with AST Nodes

```swift
// Create nodes programmatically
let documentNode = CodeNode(type: MarkdownElement.document, value: "")
let headerNode = CodeNode(type: MarkdownElement.header1, value: "Title")
let paragraphNode = CodeNode(type: MarkdownElement.paragraph, value: "Content")

// Build AST structure
documentNode.addChild(headerNode)
documentNode.addChild(paragraphNode)

// Query AST properties
print("Document has \(documentNode.children.count) children")
print("Header depth: \(headerNode.depth)")
print("Total nodes in subtree: \(documentNode.subtreeCount)")

// Modify AST structure
let newHeader = CodeNode(type: MarkdownElement.header2, value: "Subtitle")
documentNode.insertChild(newHeader, at: 1)

// Remove nodes
let removedNode = documentNode.removeChild(at: 0)
print("Removed node: \(removedNode.value)")
```

### Custom Consumer Implementation

```swift
// Example of implementing a custom consumer
public class CustomMarkdownConsumer: CodeTokenConsumer {
    public func canConsume(_ token: CodeToken) -> Bool {
        // Check if this consumer can handle the token
        guard let mdToken = token as? MarkdownToken else { return false }
        return mdToken.kind == .customMarker
    }
    
    public func consume(context: inout CodeContext, token: CodeToken) -> Bool {
        guard canConsume(token) else { return false }
        
        // Create a new node for the custom element
        let customNode = CodeNode(type: MarkdownElement.text, value: token.text)
        context.currentNode.addChild(customNode)
        
        // Advance the token consumer
        context.advanceTokenConsumer()
        return true
    }
}
```

## Testing & Examples

### Running Tests

The project includes comprehensive test suites to verify Markdown parsing functionality:

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test cases
swift test --filter SwiftParserTests.testMarkdownBasicParsing
swift test --filter SwiftParserTests.testMarkdownFootnotes
swift test --filter SwiftParserTests.testMarkdownCitations
```

### Test Coverage

The test suite covers:

#### Basic Markdown Elements
- Headers (H1-H6)
- Paragraphs
- Emphasis and strong emphasis
- Inline code and code blocks
- Links and images
- Lists (ordered, unordered, task lists)
- Block quotes
- Horizontal rules

#### Advanced Features
- Nested emphasis structures
- Complex list hierarchies
- Footnote definitions and references
- Citation definitions and references
- HTML inline elements
- Autolinks

#### Edge Cases
- Malformed syntax recovery
- Prefix ambiguity resolution
- Backtracking scenarios
- Empty elements
- Nested structures

### Example Test Cases

#### Basic Elements Test
```swift
func testMarkdownBasicParsing() {
    let parser = SwiftParser()
    let markdown = "# Title\n\nThis is a paragraph."
    let result = parser.parseMarkdown(markdown)
    
    XCTAssertFalse(result.hasErrors)
    XCTAssertEqual(result.root.children.count, 2)
    
    let headers = result.markdownNodes(ofType: .header1)
    XCTAssertEqual(headers.count, 1)
    XCTAssertEqual(headers.first?.value, "Title")
}
```

#### Footnote System Test
```swift
func testMarkdownFootnotes() {
    let markdown = """
    Text with footnote[^1] and another[^note].
    
    [^1]: First footnote.
    [^note]: Second footnote.
    """
    
    let language = MarkdownLanguage()
    let result = language.parse(markdown)
    
    let footnoteRefs = result.node.findAll { 
        ($0.type as? MarkdownElement) == .footnoteReference 
    }
    let footnoteDefs = result.node.findAll { 
        ($0.type as? MarkdownElement) == .footnoteDefinition 
    }
    
    XCTAssertEqual(footnoteRefs.count, 2)
    XCTAssertEqual(footnoteDefs.count, 2)
}
```

#### Citation System Test
```swift
func testMarkdownCitations() {
    let markdown = """
    Research shows[@smith2023] that citations[@jones2022] work.
    
    [@smith2023]: Smith, J. (2023). Example Paper.
    [@jones2022]: Jones, A. (2022). Another Paper.
    """
    
    let language = MarkdownLanguage()
    let result = language.parse(markdown)
    
    let citationRefs = result.node.findAll { 
        ($0.type as? MarkdownElement) == .citationReference 
    }
    let citationDefs = result.node.findAll { 
        ($0.type as? MarkdownElement) == .citation 
    }
    
    XCTAssertEqual(citationRefs.count, 2)
    XCTAssertEqual(citationDefs.count, 2)
}
```

### Performance Characteristics

#### Parsing Performance
- **Time Complexity**: O(n) for most elements, O(n²) for complex nested emphasis
- **Space Complexity**: O(n) for AST storage
- **Memory Usage**: Efficient node reuse and minimal token storage

#### Optimization Features
- **Lazy Evaluation**: Consumers are only invoked when needed
- **Early Exit**: Failed consumer attempts exit quickly
- **Container Reuse**: AST nodes are reused where possible
- **Minimal Backtracking**: Only used for complex emphasis structures

#### Benchmarking
```swift
func benchmarkMarkdownParsing() {
    let largeMarkdown = String(repeating: "# Header\n\nParagraph with **bold** text.\n\n", count: 1000)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    let parser = SwiftParser()
    let result = parser.parseMarkdown(largeMarkdown)
    let endTime = CFAbsoluteTimeGetCurrent()
    
    print("Parsed \(largeMarkdown.count) characters in \(endTime - startTime) seconds")
    print("Generated \(result.root.subtreeCount) AST nodes")
}
```

## Project Structure

```
swift-parser/
├── Package.swift                     # Swift Package Manager configuration
├── README.md                        # Project overview
├── MARKDOWN_PARSER.md               # This documentation
├── Sources/
│   └── SwiftParser/
│       ├── SwiftParser.swift        # Main parser interface
│       ├── Core/                    # Core parsing framework
│       │   ├── CodeContext.swift    # Parsing context
│       │   ├── CodeElement.swift    # Element protocol
│       │   ├── CodeError.swift      # Error handling
│       │   ├── CodeLanguage.swift   # Language protocol
│       │   ├── CodeNode.swift       # AST node implementation
│       │   ├── CodeParser.swift     # Core parser logic
│       │   ├── CodeToken.swift      # Token definitions
│       │   ├── CodeTokenConsumer.swift  # Consumer protocol
│       │   └── CodeTokenizer.swift  # Tokenization interface
│       └── Markdown/               # Markdown-specific implementation
│           ├── MarkdownBlockConsumers.swift   # Block-level consumers
│           ├── MarkdownElement.swift          # Markdown elements
│           ├── MarkdownInlineConsumers.swift  # Inline consumers
│           ├── MarkdownLanguage.swift         # Markdown language
│           ├── MarkdownLinkConsumers.swift    # Link/image consumers
│           ├── MarkdownMiscConsumers.swift    # Utility consumers
│           ├── MarkdownToken.swift            # Markdown tokens
│           └── MarkdownTokenizer.swift        # Markdown tokenizer
└── Tests/
    └── SwiftParserTests/
        ├── SwiftParserTests.swift   # Main test suite
        └── ListDemoTests.swift      # List-specific tests
```

## Building and Installation

### Requirements
- Swift 6.0 or later
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+ (for iOS/macOS development)

### Swift Package Manager
Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/your-username/swift-parser.git", from: "1.0.0")
]
```

### Xcode Project Generation
This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```bash
# Install XcodeGen
brew install xcodegen

# Generate Xcode project
xcodegen
```

### Building
```bash
# Build the package
swift build

# Build for release
swift build -c release
```

## Extending the Parser

### Adding New Markdown Elements

To add support for new Markdown elements, follow these steps:

#### 1. Define the Element
Add new cases to `MarkdownElement` enum:
```swift
// In MarkdownElement.swift
public enum MarkdownElement: CodeElement, CaseIterable {
    // ... existing cases ...
    case customElement
    case customInlineElement
    
    // Update description method
    public var description: String {
        switch self {
        // ... existing cases ...
        case .customElement: return "customElement"
        case .customInlineElement: return "customInlineElement"
        }
    }
}
```

#### 2. Create Token Types
Add token types to `MarkdownToken`:
```swift
// In MarkdownToken.swift
public enum MarkdownTokenKind: String, CaseIterable {
    // ... existing cases ...
    case customMarker = "CUSTOM_MARKER"
}
```

#### 3. Implement Consumer
Create a consumer class:
```swift
public class CustomElementConsumer: CodeTokenConsumer {
    public func canConsume(_ token: CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        return mdToken.kind == .customMarker
    }
    
    public func consume(context: inout CodeContext, token: CodeToken) -> Bool {
        guard canConsume(token) else { return false }
        
        // Parse the custom element
        let customNode = CodeNode(type: MarkdownElement.customElement, value: token.text)
        context.currentNode.addChild(customNode)
        
        // Advance token consumer
        context.advanceTokenConsumer()
        return true
    }
}
```

#### 4. Register Consumer
Add to `MarkdownLanguage`:
```swift
// In MarkdownLanguage.swift
public class MarkdownLanguage: CodeLanguage {
    public init() {
        super.init(
            consumers: [
                // ... existing consumers ...
                CustomElementConsumer(),
            ]
        )
    }
}
```

#### 5. Update Tokenizer
Modify `MarkdownTokenizer` to recognize the new syntax:
```swift
// In MarkdownTokenizer.swift
private func tokenizeCustomElement(_ text: String, at index: inout String.Index) -> MarkdownToken? {
    // Implementation for recognizing custom syntax
    // Return appropriate MarkdownToken
}
```

### Creating Custom Languages

You can create entirely custom languages by subclassing `CodeLanguage`:

```swift
public class CustomMarkdownLanguage: CodeLanguage {
    public init() {
        super.init(
            consumers: [
                // Only include desired consumers
                MarkdownHeaderConsumer(),
                MarkdownParagraphConsumer(),
                MarkdownEmphasisConsumer(),
                // Skip advanced features if not needed
            ]
        )
    }
    
    public override var rootElement: any CodeElement {
        return MarkdownElement.document
    }
}
```

### Plugin Architecture

The parser supports a plugin-like architecture through consumer registration:

```swift
// Create a plugin manager
class MarkdownPluginManager {
    private var additionalConsumers: [CodeTokenConsumer] = []
    
    func registerPlugin(_ consumer: CodeTokenConsumer) {
        additionalConsumers.append(consumer)
    }
    
    func createLanguage() -> MarkdownLanguage {
        let language = MarkdownLanguage()
        // Add plugins to language
        for consumer in additionalConsumers {
            language.addConsumer(consumer)
        }
        return language
    }
}
```

## Contributing

### Development Setup
1. Clone the repository
2. Install dependencies: `swift package resolve`
3. Generate Xcode project: `xcodegen`
4. Open `SwiftParser.xcodeproj`

### Code Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose

### Testing Requirements
- All new features must include comprehensive tests
- Maintain test coverage above 90%
- Include edge case testing
- Add performance benchmarks for new parsing logic

### Pull Request Process
1. Create a feature branch: `git checkout -b feature/new-element`
2. Implement the feature with tests
3. Update documentation
4. Ensure all tests pass: `swift test`
5. Submit pull request with detailed description

### Issue Reporting
When reporting bugs, include:
- Swift version and platform
- Minimal reproduction case
- Expected vs actual behavior
- Any error messages or stack traces

## Future Roadmap

### Planned Features
- ✅ **Math Support**: LaTeX-style math expressions (`$inline$`, `$$block$$`)
- [ ] **Definition Lists**: Support for definition list syntax
- [ ] **Admonitions**: Support for warning/info/note blocks
- [ ] **Mermaid Diagrams**: Inline diagram support
- [ ] **Custom Containers**: Generic container syntax (:::)
- [ ] **Syntax Highlighting**: Code block syntax highlighting
- [ ] **Export Formats**: HTML, PDF, and other output formats

### Performance Improvements
- [ ] **Streaming Parser**: Support for large document streaming
- [ ] **Parallel Processing**: Multi-threaded parsing for large documents
- [ ] **Memory Optimization**: Reduce memory footprint for large ASTs
- [ ] **Incremental Parsing**: Update AST for document changes

### Developer Experience
- [ ] **VS Code Extension**: Syntax highlighting and error reporting
- [ ] **Debug Tools**: AST visualization and inspection tools
- [ ] **Performance Profiler**: Built-in performance analysis
- [ ] **Documentation Generator**: Auto-generate API documentation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [CommonMark Specification](https://spec.commonmark.org/) for the base Markdown standard
- [GitHub Flavored Markdown](https://github.github.com/gfm/) for extension specifications
- Swift community for language design inspiration
- Contributors and testers who helped improve the parser

---

*Last updated: 2025-07-20*

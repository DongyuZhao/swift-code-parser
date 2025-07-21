# Markdown Parser

This document provides an overview of the Markdown parser built on top of the SwiftParser core. The parser follows the CommonMark specification and uses configurable builders to generate different node types while handling prefix ambiguities.

## Features

### CommonMark Support
- ✅ ATX headers (\# Heading)
- ✅ Paragraphs
- ✅ Emphasis (\*italic\*, \*\*bold\*\*) with nested structures and backtracking
- ✅ Inline code (\`code\`)
- ✅ Fenced code blocks (\`\`\`code\`\`\`)
- ✅ Block quotes (\> quote) with multi-line merging
- ✅ Lists (ordered and unordered) with automatic numbering
- ✅ Links (\[text\]\(URL\) and reference style)
- ✅ Images (\!\[alt\]\(URL\))
- ✅ Autolinks (\<URL\>)
- ✅ Horizontal rules (\-\-\-)
- ✅ HTML inline elements
- ✅ HTML block elements
- ✅ Line break handling

### GitHub Flavored Markdown (GFM) Extensions
- ✅ Tables
- ✅ Strikethrough (\~\~text\~\~)
- ✅ Task lists (\- \[ \], \- \[x\])

### Academic Extensions
- ✅ **Footnotes**: Definition and reference support (\[\^1\]: footnote, \[^1\])
- ✅ **Citations**: Academic citation support (\[\@author2023\]: reference, \[\@author2023\])
- ✅ **Math formulas**: inline (`$math$`) and block (`$$math$$`)

### Other Extensions
- ✅ **Definition lists**: term/definition pairs
- ✅ **Admonitions**: note/warning/info blocks using `> [!NOTE]` style
- ✅ **Custom containers**: generic container syntax (`:::`)

### Advanced List Features
- ✅ **Unordered lists**: supports `-`, `*`, `+` markers
- ✅ **Ordered lists**: automatic numbering (1. 1. 1. → 1. 2. 3.)
- ✅ **Task lists**: GitHub-style checkboxes (- [ ] and - [x])
- ✅ **Item grouping**: correctly groups items under the same list container
- ✅ **Smart marker detection**: distinguishes list markers from emphasis markers

### Advanced Capabilities
- ✅ Partial node handling for prefix ambiguities
- ✅ Multi-builder architecture
- ✅ Configurable builder combinations
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

let language = MarkdownLanguage()
let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
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

let result = parser.parse(markdown, language: language)

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
let headers = result.root.nodes { $0.element == .heading }
for case let header as HeaderNode in headers {
    print("Header level: \(header.level)")
}

// Find all links
let links = result.root.nodes { $0.element == .link }
for case let link as LinkNode in links {
    print("URL: \(link.url)")
}

// Find all code blocks
let codeBlocks = result.root.nodes { $0.element == .codeBlock }
for case let block as CodeBlockNode in codeBlocks {
    print("Language: \(block.language ?? \"none\")")
    print("Code: \(block.source)")
}

// Find lists
let unorderedLists = result.root.nodes { $0.element == .unorderedList }
let orderedLists = result.root.nodes { $0.element == .orderedList }
let taskLists = result.root.nodes { $0.element == .taskList }

print("Unordered lists: \(unorderedLists.count)")
print("Ordered lists: \(orderedLists.count)")
print("Task lists: \(taskLists.count)")

// Find footnotes and citations
let footnoteDefinitions = result.root.nodes { $0.element == .footnote }
let citationDefinitions = result.root.nodes { $0.element == .citation }
let citationReferences = result.root.nodes { $0.element == .citationReference }

print("Footnotes: \(footnoteDefinitions.count)")
print("Citations: \(citationDefinitions.count)")
print("Citation refs: \(citationReferences.count)")

// Process footnotes
for case let footnote as FootnoteNode in footnoteDefinitions {
    print("Footnote ID: \(footnote.identifier)")
    print("Content: \(footnote.content)")
}

// Process citations
for case let citation as CitationNode in citationDefinitions {
    print("Citation ID: \(citation.identifier)")
    print("Content: \(citation.content)")
}
```

### Traversing the AST

```swift
// Depth-first traversal
result.root.dfs { node in
    print(node.element.rawValue)
}

// Breadth-first traversal
result.root.bfs { node in
    // Handle each node
}

// Find a specific node
let firstParagraph = result.root.first { node in
    (node.type as? MarkdownElement) == .paragraph
}

// Find all list items
let allListItems = result.root.nodes { node in
    let element = node.element
    return element == .listItem || element == .taskListItem
}
```

## Advanced Usage

### Using Core Parser with Custom Configuration

```swift
import SwiftParser

// Create a custom language with specific builder combinations
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
let documentNode = CodeNode<MarkdownNodeElement>(element: .document)
let headerNode = CodeNode<MarkdownNodeElement>(element: .heading)
let paragraphNode = CodeNode<MarkdownNodeElement>(element: .paragraph)

// Build AST structure
documentNode.append(headerNode)
documentNode.append(paragraphNode)

// Query AST properties
print("Document has \(documentNode.children.count) children")
print("Header depth: \(headerNode.depth)")
print("Total nodes in subtree: \(documentNode.count)")

// Modify AST structure
let newHeader = CodeNode<MarkdownNodeElement>(element: .heading)
documentNode.insert(newHeader, at: 1)

// Remove nodes
let removedNode = documentNode.remove(at: 0)
print("Removed node element: \(removedNode.element)")
```

### Custom Builder Implementation

```swift
// Example of implementing a custom builder
public class CustomElementBuilder: CodeNodeBuilder {
    public func build(from context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .customMarker else { return false }

        let customNode = CodeNode<MarkdownNodeElement>(element: .customElement)
        context.current.append(customNode)
        context.consuming += 1
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
swift test --filter MarkdownInlineBuilderTests/testItalicBuilderParsesItalicText
swift test --filter MarkdownReferenceFootnoteTests/testFootnoteDefinitionAndReference
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
    let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
    let language = MarkdownLanguage()
    let markdown = "# Title\n\nThis is a paragraph."
    let result = parser.parse(markdown, language: language)
    
    XCTAssertFalse(result.hasErrors)
    XCTAssertEqual(result.root.children.count, 2)
    
    let headers = result.root.nodes { $0.element == .heading }
    XCTAssertEqual(headers.count, 1)
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
- **Lazy Evaluation**: Builders are only invoked when needed
- **Early Exit**: Failed builder attempts exit quickly
- **Container Reuse**: AST nodes are reused where possible
- **Minimal Backtracking**: Only used for complex emphasis structures

#### Benchmarking
```swift
func benchmarkMarkdownParsing() {
    let largeMarkdown = String(repeating: "# Header\n\nParagraph with **bold** text.\n\n", count: 1000)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    let parser = SwiftParser()
    let result = parser.parse(largeMarkdown, language: language)
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
│       │   ├── CodeNodeBuilder.swift    # Node builder protocol
│       │   └── CodeTokenizer.swift  # Tokenization interface
│       └── Markdown/               # Markdown-specific implementation
│           ├── Builders/                     # Node builders
│           ├── MarkdownContextState.swift    # Parsing state
│           ├── MarkdownLanguage.swift        # Markdown language
│           ├── MarkdownNodeElement.swift     # Node element definitions
│           ├── MarkdownNodes.swift           # Node implementations
│           ├── MarkdownTokenizer.swift       # Tokenizer
│           └── MarkdownTokens.swift          # Token definitions
└── Tests/
    └── SwiftParserTests/
        ├── Core/
        │   └── CodeNodeStructureTests.swift
        └── Markdown/
            ├── Builders/
            │   ├── MarkdownAllFeaturesBuilderTests.swift
            │   ├── MarkdownBlockElementTests.swift
            │   ├── MarkdownInlineBuilderTests.swift
            │   ├── MarkdownNestedEmphasisTests.swift
            │   ├── MarkdownReferenceFootnoteTests.swift
            │   └── MarkdownTokenBuilderTests.swift
            └── Tokenizer/
                ├── MarkdownTokenizerBasicTests.swift
                ├── MarkdownTokenizerComplexTests.swift
                ├── MarkdownTokenizerFormulaTests.swift
                └── MarkdownTokenizerHTMLTests.swift
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
Add new cases to `MarkdownNodeElement` enum:
```swift
// In MarkdownNodeElement.swift
public enum MarkdownNodeElement: String, CaseIterable, CodeNodeElement {
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
Add token types to `MarkdownTokenElement`:
```swift
// In MarkdownTokens.swift
public enum MarkdownTokenElement: String, CaseIterable, CodeTokenElement {
    // ... existing cases ...
    case customMarker = "CUSTOM_MARKER"
}
```

#### 3. Implement Builder
Create a builder class:

#### 4. Register Builder
Add to `MarkdownLanguage`:
```swift
// In MarkdownLanguage.swift
public class MarkdownLanguage: CodeLanguage {
    public init() {
        super.init(
            consumers: [
                // ... existing builders ...
                CustomElementBuilder(),
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
                // Only include desired builders
                MarkdownHeadingBuilder(),
                MarkdownParagraphBuilder(),
                MarkdownListBuilder(),
                // Skip advanced features if not needed
            ]
        )
    }

    public override var rootElement: any CodeElement {
        return MarkdownNodeElement.document
    }
}
```

### Plugin Architecture

The parser supports a plugin-like architecture through builder registration:

```swift
// Create a plugin manager
class MarkdownPluginManager {
    private var additionalBuilders: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>] = []

    func registerPlugin(_ builder: any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>) {
        additionalBuilders.append(builder)
    }

    func createLanguage() -> MarkdownLanguage {
        let base = MarkdownLanguage()
        return MarkdownLanguage(consumers: base.builders + additionalBuilders)
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

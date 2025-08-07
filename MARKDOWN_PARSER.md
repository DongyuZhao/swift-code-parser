# Markdown Parser

This document provides an overview of the Markdown parser built on top of the CodeParser core. The parser follows the CommonMark specification and uses configurable builders to generate different node types while handling prefix ambiguities.

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

## Create Custom Language

## Project Structure

## Building and Installation

### Requirements
- Swift 6.0 or later
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+ (for iOS/macOS development)

### Swift Package Manager
Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/your-username/swift-code-parser.git", from: "1.0.0")
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

## Contributing

### Development Setup
1. Clone the repository
2. Install dependencies: `swift package resolve`
3. Generate Xcode project: `xcodegen`
4. Open `CodeParser.xcodeproj`

### Code Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose

### Documentation
The codebase now contains detailed Swift documentation comments explaining the
responsibilities of core types such as `CodeParser`, `CodeConstructor` and the
inline parser.  These comments can be viewed in Xcode Quick Help or rendered by
documentation tools.

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

*Last updated: 2025-07-21*

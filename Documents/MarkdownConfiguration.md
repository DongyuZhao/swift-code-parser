# Markdown Parser Configuration Guide

The Markdown parser now provides a fully pluggable architecture that allows you to easily add or remove features by configuring which builders are included.

## Quick Start

### Standard CommonMark Parser
```swift
// Create a parser with all CommonMark features
let parser = MarkdownBlockBuilder()

// Or explicitly
let parser = MarkdownBlockBuilder.strictCommonMark()
```

### Custom Feature Sets

```swift
// Text-only parsing (no formatting)
let textOnlyParser = MarkdownBlockBuilder.textOnly()

// Basic formatting only (emphasis, strong, code)
let basicParser = MarkdownBlockBuilder(configuration: 
    MarkdownBuilderConfiguration()
        .addCoreBlockBuilders()
        .addEmphasisBuilders()
        .addCodeBuilders()
)

// Documentation-focused parsing
let docsParser = MarkdownBlockBuilder.documentation()
```

## Configuration API

### Creating Custom Configurations

```swift
// Start with empty configuration
let config = MarkdownBuilderConfiguration()

// Add specific features
config
    .addCoreBlockBuilders()          // Paragraphs (required)
    .addEmphasisBuilders()           // *emphasis* and **strong**
    .addCodeBuilders()               // `code spans`
    .addLinkBuilders()               // [links](url) and ![images](url)

// Create parser with custom configuration
let parser = MarkdownBlockBuilder(configuration: config)
```

### Feature-Based Configuration

```swift
// Enable only what you need
let config = MarkdownBuilderConfiguration()
    .textOnly()                      // Start with just text
    .addEmphasisBuilders()           // Add emphasis support
    .removeInlineBuilder(ofType: .strong)  // But remove strong emphasis

// Or use predefined feature sets
let basicConfig = MarkdownBuilderConfiguration()
    .basicFormatting()               // Text + emphasis + code

let linkConfig = MarkdownBuilderConfiguration()
    .textWithLinks()                 // Text + basic formatting + links
```

## Adding Custom Builders

### Block Builders

```swift
// Create your custom block builder
public class MyCustomBlockBuilder: MarkdownBlockBuilderProtocol {
    public var priority: Int { return 50 }
    public var blockType: MarkdownNodeElement { return .custom }
    
    public func canStart(line: [any CodeToken<MarkdownTokenElement>], state: MarkdownConstructState) -> Bool {
        // Your logic here
        return false
    }
    
    // Implement other required methods...
}

// Add to configuration
let config = MarkdownBuilderConfiguration()
    .addStandardBlockBuilders()
    .addBlockBuilder(MyCustomBlockBuilder())
```

### Inline Builders

```swift
// Create your custom inline builder
public class MyCustomInlineBuilder: MarkdownInlineBuilderProtocol {
    public var priority: Int { return 75 }
    public var inlineType: MarkdownNodeElement { return .custom }
    
    public func canHandle(tokens: [any CodeToken<MarkdownTokenElement>], position: Int, state: MarkdownConstructState) -> Bool {
        // Your logic here
        return false
    }
    
    // Implement other required methods...
}

// Add to configuration
let config = MarkdownBuilderConfiguration()
    .addStandardInlineBuilders()
    .addInlineBuilder(MyCustomInlineBuilder())
```

## Removing Features

```swift
// Remove specific features
let config = MarkdownBuilderConfiguration.standard()
    .removeInlineBuilder(ofType: .emphasis)     // Remove emphasis
    .removeInlineBuilder(ofType: .strong)       // Remove strong emphasis
    .removeBlockBuilder(ofType: .blockquote)    // Remove blockquotes

// Create minimal parser
let minimalConfig = MarkdownBuilderConfiguration()
    .addCoreBlockBuilders()          // Just paragraphs
    .addCoreInlineBuilders()         // Just text
```

## Validation

```swift
let config = MarkdownBuilderConfiguration()
    .addEmphasisBuilders()
    // Missing core builders!

do {
    try config.validate()
    let parser = MarkdownBlockBuilder(configuration: config)
} catch MarkdownConfigurationError.missingParagraphBuilder {
    print("Configuration must include a paragraph builder")
} catch {
    print("Configuration validation failed: \(error)")
}
```

## Predefined Configurations

### Standard CommonMark
```swift
let parser = MarkdownBlockBuilder(configuration: .standard())
// Includes: paragraphs, blockquotes, thematic breaks, emphasis, strong, code spans, links, images, HTML, entities
```

### GitHub Flavored Markdown
```swift
let parser = MarkdownBlockBuilder(configuration: .githubFlavored())
// Future: Will include GFM extensions like strikethrough, tables, task lists
```

### Minimal Parser
```swift
let parser = MarkdownBlockBuilder(configuration: .minimal())
// Includes: paragraphs, text only
```

### Documentation Parser
```swift
let parser = MarkdownBlockBuilder(configuration: .documentation())
// Optimized for documentation with enhanced link and code support
```

## Builder Priorities

Builders are processed in priority order (lower numbers = higher priority):

### Block Builders
- Container blocks (blockquotes): 10-50
- Leaf blocks (thematic breaks): 50-100  
- Fallback (paragraphs): 1000

### Inline Builders
- Code spans: 5
- Hard line breaks: 5
- Emphasis/Strong: 10-20
- Links/Images: 25-30
- HTML/Entities: 40-50
- Text (fallback): 1000

## Best Practices

1. **Always include core builders**: Paragraph and text builders are required
2. **Use validation**: Call `config.validate()` before creating parsers
3. **Consider priorities**: Lower priority numbers are processed first
4. **Start with presets**: Use `.standard()`, `.minimal()` etc. as starting points
5. **Test configurations**: Validate that your custom configurations work as expected

## Migration from Hardcoded Builders

### Before (Hardcoded)
```swift
// Old way - fixed set of builders
let parser = MarkdownBlockBuilder()
```

### After (Configurable)
```swift
// New way - configurable builders
let config = MarkdownBuilderConfiguration.standard()
    .removeInlineBuilder(ofType: .emphasis)    // Customize as needed
    .addInlineBuilder(MyCustomBuilder())

let parser = MarkdownBlockBuilder(configuration: config)
```

This new architecture makes the parser truly pluggable - you can easily add experimental features, remove unwanted functionality, or create specialized parsers for specific use cases.
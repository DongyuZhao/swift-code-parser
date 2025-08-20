# swift-code-parser

A powerful Swift framework for parsing and analyzing code syntax with support for multiple languages, with a focus on Markdown parsing.

## Documentation

- GitHub Flavored Markdown Spec (vendored): `Documents/Spec/Markdown/spec.md`
- Internal extension: Formula parsing spec: `Documents/Spec/Markdown/spec-900-formula-extension.md`

## Getting Started

### Requirements
- Swift 6.0 or later  
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+ (for iOS/macOS development)

### Opening in Xcode
```bash
# Open the Swift Package in Xcode
open Package.swift
```

### Building and Running
```bash
# Build the project
swift build

# Run the showcase application
swift run CodeParserShowCase

# Run tests
swift test
```

## Code Formatting

This project uses [apple/swift-format](https://github.com/apple/swift-format) for code formatting.

### Setup
The project already includes swift-format as a dependency in `Package.swift`.

### Usage

To format all Swift files in the project:
```bash
./format.sh
```

Or run swift-format commands manually:
```bash
# Format files in-place
swift run swift-format format --in-place --recursive Sources/ Tests/

# Lint files (check for formatting issues without modifying)
swift run swift-format lint --recursive Sources/ Tests/

# Format a specific file
swift run swift-format format --in-place path/to/file.swift
```

### Configuration
The formatting rules are configured in `.swift-format` file in the project root. You can modify this file to customize the formatting style according to your preferences.

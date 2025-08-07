# swift-parser

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.
To create the `SwiftParser.xcodeproj`, run:

```bash
xcodegen
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

#!/bin/bash

# Format all Swift files in the project
echo "🔧 Formatting Swift files..."

# Format the main source files
swift run swift-format format --in-place --recursive Sources/

# Format the test files
swift run swift-format format --in-place --recursive Tests/

echo "✅ Swift formatting complete!"

# Optional: Also run lint to check for issues
echo "🔍 Running swift-format lint..."
swift run swift-format lint --recursive Sources/ Tests/
echo "✅ Linting complete!"

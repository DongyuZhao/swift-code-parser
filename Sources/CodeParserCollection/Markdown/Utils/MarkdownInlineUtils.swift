import CodeParserCore
import Foundation

// Shared inline utilities for Markdown builders.
// Keep only data helpers here. Inline parsing should be delegated to
// an instance of MarkdownInlineParser (a CodeNodeBuilder).

@inlinable
func tokensToString(_ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>) -> String {
  return tokens.map { $0.text }.joined()
}

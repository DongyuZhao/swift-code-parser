import Foundation

/// Protocol for building a specific Markdown block from a list of lines.
protocol MarkdownBlockBuilder {
  /// Check if the provided line can start this block type.
  func match(line: String) -> Bool
  /// Build the block starting at `index` and append it to `root`.
  /// Implementations should update `index` to the line following the block.
  func build(lines: [String], index: inout Int, root: MarkdownNodeBase)
}

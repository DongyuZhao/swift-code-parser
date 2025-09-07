import CodeParserCore

/// Unified resolver protocol for all Markdown block parsing phases.
/// Implementations are registered under a specific phase in `MarkdownBlockBuilder`
/// and invoked via this single entry point.
public protocol MarkdownBlockResolver {
  func resolve(from context: inout MarkdownBlockContext) -> Bool
}

import CodeParserCore

/// Empty construct state for Markdown block construction.
public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement
  public init() {}
}


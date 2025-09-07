import CodeParserCore

public class MarkdownBlockContext {
  /// Current node being processed.
  /// Resolver should guarantee this node is the last open container node
  public var current: CodeNode<MarkdownNodeElement>

  /// Tokens available for processing
  public var tokens: [any CodeToken<MarkdownTokenElement>]

  /// The tokens already consumed
  public var consumed: Int = 0

  /// Set to true if the resolver want to yield the remaining tokens for re-processing in the same phase.
  /// E.g. block quote resolver may want to yield remaining tokens to allow other resolvers
  /// to process the content inside the block quote.
  /// This is only valid during the creation and continuation phases.
  /// During construction and finalization phases, this flag is ignored.
  public var refreshed: Bool = false


  public init(
    current: CodeNode<MarkdownNodeElement>,
    tokens: [any CodeToken<MarkdownTokenElement>] = []
  ) {
    self.current = current
    self.tokens = tokens
  }
}
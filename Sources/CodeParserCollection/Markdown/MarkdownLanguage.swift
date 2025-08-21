import CodeParserCore
import Foundation

// MARK: - Markdown Language Implementation
/// Default Markdown language implementation following CommonMark with optional
/// extensions.
///
/// The language exposes a set of token and node builders that together
/// understand Markdown syntax. The initializer allows callers to supply a
/// custom list of builders to enable or disable features.
public class MarkdownLanguage: CodeLanguage {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // MARK: - Language Components
  public var tokens: [any CodeTokenBuilder<MarkdownTokenElement>]
  public let nodes: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>]

  // MARK: - Initialization
  /// Create a Markdown language with the provided builders.
  ///
  /// - Parameter consumers: Node builders to be used when constructing the
  ///   document AST. Passing a custom set allows features to be enabled or
  ///   disabled.
  public init() {
    self.nodes = [
      MarkdownBlockBuilder(),
    ]
    self.tokens = [
      MarkdownNewlineTokenBuilder(),
      MarkdownWhitespaceTokenBuilder(),
      MarkdownEntitiesTokenBuilder(),
      MarkdownCharactersTokenBuilder(),
      MarkdownPunctuationTokenBuilder(),
    ]
  }

  // MARK: - Language Protocol Implementation
  public func root() -> CodeNode<MarkdownNodeElement> {
    return DocumentNode()
  }

  public func state() -> (any CodeConstructState<Node, Token>)? {
    return MarkdownConstructState()
  }

  public func state() -> (any CodeTokenState<MarkdownTokenElement>)? {
    return MarkdownTokenState()
  }

  public func eof(at range: Range<String.Index>) -> (any CodeToken<MarkdownTokenElement>)? {
    return MarkdownToken.eof(at: range)
  }
}

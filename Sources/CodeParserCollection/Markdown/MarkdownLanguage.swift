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
    ]
    self.tokens = [
      MarkdownWhitespaceTokenBuilder(),
      MarkdownCharacterTokenBuilder(),
      MarkdownNumberTokenBuilder(),
      MarkdownTextTokenBuilder(characters: Set(MarkdownCharacterTokenBuilder.characters.keys)),
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
    nil
  }

  public func eof(at range: Range<String.Index>) -> (any CodeToken<MarkdownTokenElement>)? {
    return MarkdownToken.eof(at: range)
  }
}

// MARK: - Language Capabilities
extension MarkdownLanguage {
  /// Check if the language supports a specific feature
  public func supports(_ feature: MarkdownFeature) -> Bool {
    // TODO: Implement feature checking based on configured consumers
    return false
  }

  /// Get all supported features
  public var features: Set<MarkdownFeature> {
    // TODO: Implement feature detection based on configured consumers
    return Set()
  }

  /// Get the language version/specification
  public var version: String {
    return "1.0.0"
  }

  /// Get the specification this language implements
  public var specification: String {
    return "CommonMark 0.30"
  }
}

// MARK: - Markdown Features Enumeration
public enum MarkdownFeature: String, CaseIterable {
  // CommonMark Core
  case paragraphs = "paragraphs"
  case headings = "headings"
  case thematicBreaks = "thematic_breaks"
  case blockquotes = "blockquotes"
  case lists = "lists"
  case codeBlocks = "code_blocks"
  case htmlBlocks = "html_blocks"
  case emphasis = "emphasis"
  case strongEmphasis = "strong_emphasis"
  case inlineCode = "inline_code"
  case links = "links"
  case images = "images"
  case autolinks = "autolinks"
  case htmlInline = "html_inline"
  case hardBreaks = "hard_breaks"
  case softBreaks = "soft_breaks"

  // GFM Extensions
  case tables = "tables"
  case strikethrough = "strikethrough"
  case taskLists = "task_lists"
  case disallowedRawHTML = "disallowed_raw_html"

  // Math Extensions
  case mathInline = "math_inline"
  case mathBlocks = "math_blocks"

  // Extended Features
  case footnotes = "footnotes"
  case definitionLists = "definition_lists"
  case abbreviations = "abbreviations"
  case emoji = "emoji"
  case mentions = "mentions"
  case hashtags = "hashtags"
  case wikiLinks = "wiki_links"
  case keyboardKeys = "keyboard_keys"
  case frontmatter = "frontmatter"
  case admonitions = "admonitions"
  case spoilers = "spoilers"
  case details = "details"
  case syntaxHighlighting = "syntax_highlighting"
  case smartPunctuation = "smart_punctuation"
  case typographicReplacements = "typographic_replacements"
  case tableOfContents = "table_of_contents"
  case headingAnchors = "heading_anchors"
  case customContainers = "custom_containers"
}

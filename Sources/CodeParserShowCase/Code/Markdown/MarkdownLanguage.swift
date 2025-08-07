import Foundation
import CodeParser

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
    public init(
        consumers: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>] = [
            MarkdownReferenceDefinitionBuilder(),
            MarkdownHeadingBuilder(),
            MarkdownThematicBreakBuilder(),
            MarkdownFencedCodeBuilder(),
            MarkdownFormulaBlockBuilder(),
            MarkdownHTMLBlockBuilder(),
            MarkdownDefinitionListBuilder(),
            MarkdownAdmonitionBuilder(),
            MarkdownCustomContainerBuilder(),
            MarkdownTableBuilder(),
            MarkdownListBuilder(),
            MarkdownBlockquoteBuilder(),
            MarkdownParagraphBuilder(),
            MarkdownNewlineBuilder(),
            MarkdownEOFBuilder()
        ]
    ) {
        self.nodes = consumers
        self.tokens = [
            MarkdownCodeTokenBuilder(),
            MarkdownFormulaTokenBuilder(),
            MarkdownWhitespaceTokenBuilder(),
            MarkdownURLTokenBuilder(),
            MarkdownHTMLTokenBuilder(),
            MarkdownCustomContainerTokenBuilder(),
            MarkdownSingleCharacterTokenBuilder(),
            MarkdownNumberTokenBuilder(),
            MarkdownTextTokenBuilder(singleCharacterMap: MarkdownSingleCharacterTokenBuilder.mapping)
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

// MARK: - Language Configuration
extension MarkdownLanguage {
    /// Configuration options for the Markdown language
    public struct Configuration: Sendable {
        /// Enable CommonMark features
        public var commonMark: Bool = true

        /// Enable GitHub Flavored Markdown extensions
        public var gfm: Bool = false

        /// Enable math support (LaTeX/TeX)
        public var math: Bool = false

        /// Enable tables
        public var tables: Bool = false

        /// Enable strikethrough
        public var strikethrough: Bool = false

        /// Enable task lists
        public var taskLists: Bool = false

        /// Enable footnotes
        public var footnotes: Bool = false

        /// Enable definition lists
        public var definitionLists: Bool = false

        /// Enable abbreviations
        public var abbreviations: Bool = false

        /// Enable HTML blocks and inline HTML
        public var html: Bool = true

        /// Enable autolinks
        public var autolinks: Bool = true

        /// Enable emoji shortcodes
        public var emoji: Bool = false

        /// Enable mentions (@username)
        public var mentions: Bool = false

        /// Enable hashtags (#tag)
        public var hashtags: Bool = false

        /// Enable wiki links ([[link]])
        public var wikiLinks: Bool = false

        /// Enable keyboard keys (<kbd>key</kbd>)
        public var keyboardKeys: Bool = false

        /// Enable frontmatter parsing
        public var frontmatter: Bool = false

        /// Enable YAML frontmatter
        public var yamlFrontmatter: Bool = false

        /// Enable TOML frontmatter
        public var tomlFrontmatter: Bool = false

        /// Enable JSON frontmatter
        public var jsonFrontmatter: Bool = false

        /// Enable custom admonitions/callouts
        public var admonitions: Bool = false

        /// Enable spoilers
        public var spoilers: Bool = false

        /// Enable details/summary blocks
        public var details: Bool = false

        /// Enable syntax highlighting for code blocks
        public var syntaxHighlighting: Bool = false

        /// Enable line numbers in code blocks
        public var lineNumbers: Bool = false

        /// Enable smart punctuation (curly quotes, em dashes, etc.)
        public var smartPunctuation: Bool = false

        /// Enable typographic replacements
        public var typographicReplacements: Bool = false

        /// Enable hard line breaks
        public var hardLineBreaks: Bool = false

        /// Enable soft line breaks
        public var softLineBreaks: Bool = true

        /// Enable link reference definitions
        public var linkReferences: Bool = true

        /// Enable image reference definitions
        public var imageReferences: Bool = true

        /// Enable table of contents generation
        public var tableOfContents: Bool = false

        /// Enable heading anchor generation
        public var headingAnchors: Bool = false

        /// Enable unsafe HTML (allows all HTML tags)
        public var unsafeHTML: Bool = false

        /// Enable raw HTML blocks
        public var rawHTML: Bool = true

        /// Enable custom containers
        public var customContainers: Bool = false

        /// Enable plugins
        public var plugins: Bool = false

        /// Default configuration with CommonMark features
        public static let `default` = Configuration()

        /// CommonMark-compliant configuration
        public static let commonMark = Configuration(
            commonMark: true,
            gfm: false,
            math: false,
            tables: false,
            strikethrough: false,
            taskLists: false,
            footnotes: false,
            definitionLists: false,
            abbreviations: false,
            emoji: false,
            mentions: false,
            hashtags: false,
            wikiLinks: false,
            keyboardKeys: false,
            frontmatter: false,
            admonitions: false,
            spoilers: false,
            details: false
        )

        /// GitHub Flavored Markdown configuration
        public static let gfm = Configuration(
            commonMark: true,
            gfm: true,
            math: false,
            tables: true,
            strikethrough: true,
            taskLists: true,
            footnotes: false,
            definitionLists: false,
            abbreviations: false,
            emoji: true,
            mentions: true,
            hashtags: true,
            wikiLinks: false,
            keyboardKeys: false,
            frontmatter: false,
            admonitions: false,
            spoilers: false,
            details: false
        )

        /// Full-featured configuration
        public static let full = Configuration(
            commonMark: true,
            gfm: true,
            math: true,
            tables: true,
            strikethrough: true,
            taskLists: true,
            footnotes: true,
            definitionLists: true,
            abbreviations: true,
            emoji: true,
            mentions: true,
            hashtags: true,
            wikiLinks: true,
            keyboardKeys: true,
            frontmatter: true,
            yamlFrontmatter: true,
            tomlFrontmatter: true,
            jsonFrontmatter: true,
            admonitions: true,
            spoilers: true,
            details: true,
            syntaxHighlighting: true,
            lineNumbers: true,
            smartPunctuation: true,
            typographicReplacements: true,
            tableOfContents: true,
            headingAnchors: true,
            customContainers: true,
            plugins: true
        )
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

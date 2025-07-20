import Foundation

public class MarkdownContextState: CodeContextState {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    /// Stack of open emphasis/strong delimiters. Each entry stores the node to
    /// be created once closed, its parent container, the index at which the
    /// delimiter appeared, the token element (`*` or `_`), and the delimiter
    /// length (1 for emphasis, 2 for strong).
    public var openEmphasis: [(node: MarkdownNodeBase, parent: MarkdownNodeBase, startIndex: Int, element: MarkdownTokenElement, length: Int)] = []

    /// Pending delimiter run that has not yet been processed. We accumulate
    /// consecutive `*` or `_` tokens here until a non-delimiter token is
    /// encountered.
    public var pendingDelimiterElement: MarkdownTokenElement?
    public var pendingDelimiterCount: Int = 0

    /// Indicates that an emphasis delimiter was just opened. This prevents the
    /// next text token from merging with a previous `TextNode`.
    public var justOpenedDelimiter: Bool = false

    public init() {}
}

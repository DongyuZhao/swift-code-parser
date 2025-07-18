import Foundation

public class MarkdownContextState: CodeContextState {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    /// Stack of open emphasis/strong nodes: the node, its parent, delimiter element, and delimiter length
    public var openEmphasis: [(node: MarkdownNodeBase, parent: MarkdownNodeBase, element: MarkdownTokenElement, length: Int)] = []
    public init() {}
}

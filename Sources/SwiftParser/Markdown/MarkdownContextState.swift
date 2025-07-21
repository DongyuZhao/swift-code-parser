import Foundation

public class MarkdownContextState: CodeConstructState {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement

    /// Stack for nested list processing
    public var listStack: [ListNode] = []
    public var currentDefinitionList: DefinitionListNode?

    public init() {}
}

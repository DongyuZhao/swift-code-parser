import Foundation

public class MarkdownContextState: CodeContextState {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement

    /// Stack for nested list processing
    public var listStack: [ListNode] = []

    public init() {}
}

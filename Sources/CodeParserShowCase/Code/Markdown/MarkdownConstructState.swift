import Foundation
import SwiftParser

public class MarkdownConstructState: CodeConstructState {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement

    /// Stack for nested list processing
    public var listStack: [ListNode] = []
    public var currentDefinitionList: DefinitionListNode?

    public init() {}
}

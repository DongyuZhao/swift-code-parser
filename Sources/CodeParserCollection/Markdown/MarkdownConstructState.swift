import CodeParserCore
import Foundation

public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  /// Tracks whether the previous parsed line was blank. This is used for
  /// constructs such as indented code blocks that require a blank line
  /// separation before they can start.
  public var previousLineBlank: Bool

  public init(previousLineBlank: Bool = true) {
    self.previousLineBlank = previousLineBlank
  }
}

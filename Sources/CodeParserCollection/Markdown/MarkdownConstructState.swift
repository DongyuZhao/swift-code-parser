import CodeParserCore
import Foundation

/// Delimiter information for emphasis/strong parsing
public struct EmphasisDelimiter {
  public let character: Character
  public let count: Int
  public let tokenIndex: Int
  public let canOpen: Bool
  public let canClose: Bool
  public let isActive: Bool
  
  public init(character: Character, count: Int, tokenIndex: Int, canOpen: Bool, canClose: Bool, isActive: Bool = true) {
    self.character = character
    self.count = count
    self.tokenIndex = tokenIndex
    self.canOpen = canOpen
    self.canClose = canClose
    self.isActive = isActive
  }
  
  public func withCount(_ newCount: Int) -> EmphasisDelimiter {
    return EmphasisDelimiter(
      character: character,
      count: newCount,
      tokenIndex: tokenIndex,
      canOpen: canOpen,
      canClose: canClose,
      isActive: isActive
    )
  }
  
  public func withActive(_ active: Bool) -> EmphasisDelimiter {
    return EmphasisDelimiter(
      character: character,
      count: count,
      tokenIndex: tokenIndex,
      canOpen: canOpen,
      canClose: canClose,
      isActive: active
    )
  }
}

public class MarkdownConstructState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  /// Tracks whether the previous parsed line was blank. This is used for
  /// constructs such as indented code blocks that require a blank line
  /// separation before they can start.
  public var previousLineBlank: Bool
  
  /// Stack of emphasis delimiters for CommonMark compliant parsing
  /// This maintains state across inline element processing for proper nesting
  public var delimiterStack: [EmphasisDelimiter]

  public init(previousLineBlank: Bool = true) {
    self.previousLineBlank = previousLineBlank
    self.delimiterStack = []
  }
  
  /// Clear the delimiter stack (called at block boundaries)
  public func clearDelimiterStack() {
    delimiterStack.removeAll()
  }
  
  /// Add a delimiter to the stack
  public func pushDelimiter(_ delimiter: EmphasisDelimiter) {
    delimiterStack.append(delimiter)
  }
  
  /// Remove delimiters from the stack
  public func removeDelimiters(from startIndex: Int, to endIndex: Int) {
    guard startIndex >= 0 && endIndex < delimiterStack.count && startIndex <= endIndex else {
      return
    }
    delimiterStack.removeSubrange(startIndex...endIndex)
  }
}

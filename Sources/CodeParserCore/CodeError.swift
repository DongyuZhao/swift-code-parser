import Foundation

/// Represents a parsing error encountered during tokenization or AST building.
public struct CodeError: Error {
  /// Human readable error message.
  public let message: String
  /// Range in the original source where the error occurred, if available.
  public let range: Range<String.Index>?

  /// Create a new error instance.
  /// - Parameters:
  ///   - message: Description of the problem.
  ///   - range: Optional source range that triggered the error.
  public init(_ message: String, range: Range<String.Index>? = nil) {
    self.message = message
    self.range = range
  }
}

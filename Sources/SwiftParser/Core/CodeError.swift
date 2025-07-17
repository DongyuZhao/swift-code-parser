import Foundation

public struct CodeError: Error {
    public let message: String
    public let range: Range<String.Index>?
    public init(_ message: String, range: Range<String.Index>? = nil) {
        self.message = message
        self.range = range
    }
}

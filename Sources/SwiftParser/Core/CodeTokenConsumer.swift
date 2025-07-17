import Foundation

/// Consumes a token and optionally updates the AST if it is recognized.
/// - Returns: `true` if the token was handled and the context advanced.
public protocol CodeTokenConsumer {
    func consume(context: inout CodeContext, token: any CodeToken) -> Bool
}

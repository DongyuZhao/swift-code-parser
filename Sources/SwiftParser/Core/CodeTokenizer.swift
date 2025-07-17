import Foundation

public protocol CodeTokenizer {
    func tokenize(_ input: String) -> [any CodeToken]
}

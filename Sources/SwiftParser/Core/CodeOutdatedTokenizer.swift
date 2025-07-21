import Foundation

@available(*, deprecated, renamed: "CodeTokenizer", message: "Use `CodeTokenizer` instead.")
public protocol CodeOutdatedTokenizer<Element> where Element: CodeTokenElement {
    associatedtype Element: CodeTokenElement
    func tokenize(_ input: String) -> [any CodeToken<Element>]
}

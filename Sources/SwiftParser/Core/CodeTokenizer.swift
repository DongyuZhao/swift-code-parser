import Foundation
public protocol CodeTokenizer<Element> where Element: CodeTokenElement {
    associatedtype Element: CodeTokenElement
    func tokenize(_ input: String) -> [any CodeToken<Element>]
}

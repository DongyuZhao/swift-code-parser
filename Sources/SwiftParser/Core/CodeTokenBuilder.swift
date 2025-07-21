public protocol CodeTokenBuilder<Element> where Element: CodeTokenElement {
    associatedtype Element: CodeTokenElement
    func build(from context: CodeTokenContext<Element>) -> Bool
}
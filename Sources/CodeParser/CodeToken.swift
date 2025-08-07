import Foundation

public protocol CodeTokenElement: CaseIterable, RawRepresentable where RawValue == String {}

public protocol CodeToken<Element> where Element: CodeTokenElement {
    associatedtype Element: CodeTokenElement
    var element: Element { get }
    var text: String { get }
    var range: Range<String.Index> { get }
}

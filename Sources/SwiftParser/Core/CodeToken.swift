import Foundation

public protocol CodeToken {
    var kindDescription: String { get }
    var text: String { get }
    var range: Range<String.Index> { get }
}

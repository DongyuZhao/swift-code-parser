import Foundation

public protocol CodeLanguage {
    var tokenizer: CodeTokenizer { get }
    var consumers: [CodeTokenConsumer] { get }
    var rootElement: any CodeElement { get }
}

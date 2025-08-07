//
//  CodeTokenContext.swift
//  CodeParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

public protocol CodeTokenState<Token> where Token: CodeTokenElement {
    associatedtype Token: CodeTokenElement
}

public class CodeTokenContext<Token> where Token: CodeTokenElement {
    /// The source string being parsed.
    public let source: String

    /// The current position in the source string.
    public var consuming: String.Index

    /// The tokens that have been created from the source string.
    public var tokens: [any CodeToken<Token>] = []

    /// Any errors encountered during tokenization.
    public var errors: [CodeError] = []

    /// The state of the tokenization process, which can hold additional information.
    public var state: (any CodeTokenState<Token>)?

    public convenience init(source: String, state: (any CodeTokenState<Token>)? = nil) {
        self.init(source: source, consuming: source.startIndex, state: state)
    }

    public init(source: String, consuming: String.Index, state: (any CodeTokenState<Token>)? = nil) {
        self.source = source
        self.consuming = consuming
        self.state = state
    }
}

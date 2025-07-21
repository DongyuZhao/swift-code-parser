//
//  CodeTokenBuilder.swift
//  SwiftParser
//
//  Created by Dongyu Zhao on 7/21/25.
//

public protocol CodeTokenBuilder<Token> where Token: CodeTokenElement {
    associatedtype Token: CodeTokenElement
    func build(from context: inout CodeTokenContext<Token>) -> Bool
}

    

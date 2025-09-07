//
//  CodeDebugUtils.swift
//  CodeParser
//
//  Debug utilities for AST visualization and state inspection
//

import Foundation

/// Utilities for debugging and visualizing parser state
public class CodeDebugUtils {
  
  /// Print an ASCII tree representation of the AST
  public static func printAST<Node: CodeNodeElement>(_ node: CodeNode<Node>, prefix: String = "", isLast: Bool = true) {
    let marker = isLast ? "└── " : "├── "
    let nodeType = String(describing: type(of: node))
    let elementName = node.element.rawValue
    
    print("\(prefix)\(marker)\(nodeType) (\(elementName)) [\(node.children.count) children]")
    
    let childPrefix = prefix + (isLast ? "    " : "│   ")
    
    for (index, child) in node.children.enumerated() {
      let isLastChild = index == node.children.count - 1
      printAST(child, prefix: childPrefix, isLast: isLastChild)
    }
  }
  
  /// Print token stream with detailed information
  public static func printTokens<Token: CodeTokenElement>(_ tokens: [any CodeToken<Token>]) {
    print("DEBUG-TOKENS: Token stream (\(tokens.count) tokens):")
    for (index, token) in tokens.enumerated() {
      let escapedText = token.text
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
      print("  [\(index)] \(token.element) = '\(escapedText)'")
    }
  }
  
  /// Print construction state information
  public static func printConstructState<Node: CodeNodeElement, Token: CodeTokenElement>(
    _ context: CodeConstructContext<Node, Token>
  ) {
    print("DEBUG-STATE: Construction Context:")
    print("  Current position: \(context.consuming)/\(context.tokens.count)")
    print("  Current node: \(type(of: context.current)) (\(context.current.element))")
    print("  Errors: \(context.errors.count)")
    
    if let state = context.state {
      print("  State: \(type(of: state))")
    } else {
      print("  State: nil")
    }
  }
  
  /// Print a detailed summary of AST structure with content
  public static func printASTSummary<Node: CodeNodeElement>(_ node: CodeNode<Node>, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    let nodeType = String(describing: type(of: node))
    let elementName = node.element.rawValue
    
    print("\(indent)\(nodeType) (\(elementName))")
    
    // Print additional information based on node type (without casting to specific types)
    // This avoids dependencies on specific implementations
    
    if node.children.isEmpty {
      print("\(indent)  [leaf node]")
    } else {
      print("\(indent)  [\(node.children.count) children]:")
      for child in node.children {
        printASTSummary(child, depth: depth + 1)
      }
    }
  }
}

// MARK: - Extensions for easier debugging

extension CodeNode {
  /// Quick debug print of this node and its children
  public func debugPrint() {
    CodeDebugUtils.printAST(self)
  }
  
  /// Quick debug summary with content
  public func debugSummary() {
    CodeDebugUtils.printASTSummary(self)
  }
}

extension Array where Element == any CodeToken {
  /// Quick debug print of token stream
  public func debugPrint() {
    // This requires the token to have a CodeTokenElement type, which we can't guarantee
    // So we'll make a simpler version
    print("DEBUG-TOKENS: Token stream (\(count) tokens):")
    for (index, token) in self.enumerated() {
      let escapedText = token.text
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
      print("  [\(index)] \(token.element) = '\(escapedText)'")
    }
  }
}
import CodeParserCore
import Foundation

/// Handles end-of-file processing and triggers inline content processing
/// This builder runs when EOF is encountered and processes all ContentNodes in the AST
public class MarkdownEOFBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let contentBuilder = MarkdownContentBuilder()

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Check if this is an empty line (which indicates EOF processing)
    guard context.tokens.isEmpty else {
      return false
    }
    
    // Close any open blocks when we reach EOF
    while context.current.parent != nil {
      context.current = context.current.parent!
    }
    
    // Now we should be at document root for EOF processing
    guard context.current === context.root else {
      return false
    }
    
    // Clean up trailing whitespace in code blocks before final processing
    if let rootNode = context.root as? MarkdownNodeBase {
      stripTrailingWhitespaceFromCodeBlocks(rootNode)
    }
    
    // Process all ContentNodes in the AST using the ContentBuilder
    var contentContext = CodeConstructContext<Node, Token>(
      root: context.root,
      current: context.root,
      tokens: [],
      state: context.state
    )

    _ = contentBuilder.build(from: &contentContext)

    context.consuming = context.tokens.count
    return true
  }
  
  /// Strips trailing whitespace and blank lines from code blocks
  private func stripTrailingWhitespaceFromCodeBlocks(_ node: MarkdownNodeBase) {
    // Recursively process all child nodes
    for child in node.children {
      if let childNode = child as? MarkdownNodeBase {
        stripTrailingWhitespaceFromCodeBlocks(childNode)
      }
    }
    
    // Process code blocks
    if let codeBlock = node as? CodeBlockNode {
      codeBlock.source = stripTrailingWhitespace(from: codeBlock.source)
    }
  }
  
  /// Strips trailing whitespace and blank lines from a string
  private func stripTrailingWhitespace(from source: String) -> String {
    let lines = source.components(separatedBy: .newlines)
    var processedLines: [String] = []
    
    // Process each line - preserve trailing spaces, only remove trailing newlines
    for line in lines {
      // Only trim trailing newlines, preserve trailing spaces
      processedLines.append(line.trimmingCharacters(in: .newlines))
    }
    
    // Check if the entire content is blank (only empty lines)
    let isAllBlank = processedLines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    
    if !isAllBlank {
      // Remove trailing empty lines only if there's non-blank content
      while !processedLines.isEmpty && processedLines.last?.isEmpty == true {
        processedLines.removeLast()
      }
    }
    
    return processedLines.joined(separator: "\n")
  }
}

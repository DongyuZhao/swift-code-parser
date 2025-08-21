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
}

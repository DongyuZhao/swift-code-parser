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
    
    // Handle any pending reference definition
    if let state = context.state as? MarkdownConstructState,
       let pending = state.pendingReference {
      // Add the pending reference to the AST
      context.current.append(pending.referenceNode)
      state.pendingReference = nil
    }
    
    // Validate and process all reference definitions
    if let state = context.state as? MarkdownConstructState {
      validateReferenceDefinitions(context: &context, state: state)
    }
    
    // Clean up trailing whitespace in code blocks before final processing
    if let rootNode = context.root as? MarkdownNodeBase {
      stripTrailingWhitespaceFromCodeBlocks(rootNode)
    }
    
    // Process all ContentNodes in the AST using the ContentBuilder
    // This must happen after all block parsing is complete
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
  
  /// Validates all reference definitions in the AST and handles duplicates and invalid references
  private func validateReferenceDefinitions(
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) {
    guard let rootNode = context.root as? MarkdownNodeBase else { return }
    
    var validReferences: [String: (url: String, title: String)] = [:]
    var invalidNodes: [(node: ReferenceNode, parent: MarkdownNodeBase)] = []
    
    // Process all reference nodes and validate them
    collectAndValidateReferences(
      node: rootNode,
      validReferences: &validReferences,
      invalidNodes: &invalidNodes,
      state: state
    )
  }
  
  /// Recursively collect and validate reference definitions
  private func collectAndValidateReferences(
    node: MarkdownNodeBase,
    validReferences: inout [String: (url: String, title: String)],
    invalidNodes: inout [(node: ReferenceNode, parent: MarkdownNodeBase)],
    state: MarkdownConstructState
  ) {
    var invalidIndices: [Int] = []
    
    // Process children in forward order to preserve "first wins" rule
    for (index, child) in node.children.enumerated() {
      if let referenceNode = child as? ReferenceNode {
        let normalizedId = normalizeReferenceIdentifier(referenceNode.identifier)
        
        // Validate the reference definition
        if isValidReferenceDefinition(referenceNode) {
          // Check if this is the first occurrence (first one wins)
          if validReferences[normalizedId] == nil {
            validReferences[normalizedId] = (url: referenceNode.url, title: referenceNode.title)
            state.addReferenceDefinition(identifier: referenceNode.identifier, url: referenceNode.url, title: referenceNode.title)
          }
          // Note: duplicate definitions are kept in AST but not used for resolution
        } else {
          // Invalid reference - mark for conversion
          invalidIndices.append(index)
        }
      } else if let childNode = child as? MarkdownNodeBase {
        // Recursively process child nodes
        collectAndValidateReferences(
          node: childNode,
          validReferences: &validReferences,
          invalidNodes: &invalidNodes,
          state: state
        )
      }
    }
    
    // Convert invalid references in reverse order to maintain indices
    for index in invalidIndices.reversed() {
      if let referenceNode = node.children[index] as? ReferenceNode {
        convertInvalidReferenceToParagraphInPlace(referenceNode, parent: node, at: index)
      }
    }
  }
  
  /// Check if a reference definition is valid according to CommonMark spec
  private func isValidReferenceDefinition(_ reference: ReferenceNode) -> Bool {
    // Must have non-empty identifier
    if reference.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return false
    }
    
    // Empty URL is valid if it was explicitly provided as <> 
    // We can't distinguish between missing destination and explicit <> here,
    // so we need to be more permissive and let the parsing logic handle this
    
    // Check for invalid URL patterns
    let url = reference.url.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // URL starting with [ indicates it's likely malformed (confused with another reference)
    if url.hasPrefix("[") {
      return false
    }
    
    return true
  }
  
  /// Convert an invalid reference node back to paragraph text in place
  private func convertInvalidReferenceToParagraphInPlace(_ referenceNode: ReferenceNode, parent: MarkdownNodeBase, at index: Int) {
    // Create paragraph text from the reference syntax
    let range = "".startIndex..<"".endIndex // Synthetic range
    let paragraph = ParagraphNode(range: range)
    
    // Reconstruct the reference syntax as text
    let referenceText = "[\(referenceNode.identifier)]:"
    let tokens: [any CodeToken<MarkdownTokenElement>] = [
      MarkdownToken(element: .characters, text: referenceText, range: range)
    ]
    
    let contentNode = ContentNode(tokens: tokens)
    paragraph.append(contentNode)
    
    // Replace the reference node with the paragraph at the same position
    parent.children[index] = paragraph
  }
  
  /// Convert an invalid reference node back to paragraph text
  private func convertInvalidReferenceToParagraph(_ referenceNode: ReferenceNode, parent: MarkdownNodeBase) {
    // Create paragraph text from the reference syntax
    let range = "".startIndex..<"".endIndex // Synthetic range
    let paragraph = ParagraphNode(range: range)
    
    // Reconstruct the reference syntax as text
    let referenceText = "[\(referenceNode.identifier)]:"
    let tokens: [any CodeToken<MarkdownTokenElement>] = [
      MarkdownToken(element: .characters, text: referenceText, range: range)
    ]
    
    let contentNode = ContentNode(tokens: tokens)
    paragraph.append(contentNode)
    parent.append(paragraph)
  }
  
  /// Normalize reference identifier according to CommonMark spec
  private func normalizeReferenceIdentifier(_ identifier: String) -> String {
    return identifier
      .lowercased()
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

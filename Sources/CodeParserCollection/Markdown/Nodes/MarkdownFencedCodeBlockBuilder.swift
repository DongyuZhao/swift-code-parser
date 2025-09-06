import CodeParserCore
import Foundation

/// Builder for fenced code blocks (```code``` or ~~~code~~~)
/// Implements CommonMark specification for fenced code blocks (Spec 018)
public class MarkdownFencedCodeBlockBuilder: MarkdownBlockBuilderProtocol {
  
  public let priority: Int = 40 // Medium priority
  
  public init() {}
  
  public func canHandle(block: any MarkdownBlockNode) -> Bool {
    return block.blockType == "fenced_code_block"
  }
  
  /// Fenced code blocks can interrupt other blocks
  public func canInterrupt() -> Bool {
    return true
  }
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Fenced code blocks can be indented 0-3 spaces
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces > 3 {
      return false
    }
    
    // Work directly with tokens - skip leading whitespace
    var tokenIndex = 0
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { 
      return false 
    }
    
    // Check for fence start using tokens directly
    let (isFence, _, fenceLength) = checkFencePattern(tokens: line.tokens, startIndex: tokenIndex)
    
    if isFence && fenceLength >= 3 {
      // For backticks, check that info string doesn't contain backticks
      if let firstFenceToken = line.tokens[tokenIndex].text.first,
         firstFenceToken == "`" {
        // Check remaining tokens AFTER the fence for backticks in info string
        let infoStartIndex = tokenIndex + fenceLength  // Skip past all fence tokens
        for i in infoStartIndex..<line.tokens.count {
          let token = line.tokens[i]
          if token.element == .newline || token.element == .eof {
            break
          }
          if token.element == .punctuation && token.text.contains("`") {
            return false
          }
        }
      }
      
      return true
    }
    
    return false
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let codeBlock = block as? MarkdownFencedCodeBlock,
          block.blockType == "fenced_code_block" else { return false }
    
    // If already closed, cannot continue
    if codeBlock.isClosed {
      return false
    }
    
    // Check if this line closes the fence using tokens directly
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    if leadingSpaces <= 3 {
      // Work directly with tokens - skip leading whitespace  
      var tokenIndex = 0
      while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
        tokenIndex += 1
      }
      
      guard tokenIndex < line.tokens.count else { return true }
      
      let (isFence, fenceChar, fenceLength) = checkFencePattern(tokens: line.tokens, startIndex: tokenIndex)
      
      if isFence && fenceChar == codeBlock.fenceChar && fenceLength >= codeBlock.fenceLength {
        // Skip past fence tokens to check for trailing content
        tokenIndex += fenceLength
        
        // Check that the rest of the line only contains whitespace
        var isValidClosing = true
        while tokenIndex < line.tokens.count {
          let token = line.tokens[tokenIndex]
          if token.element == .newline || token.element == .eof {
            break
          }
          if token.element != .whitespaces {
            isValidClosing = false
            break
          }
          tokenIndex += 1
        }
        
        if isValidClosing {
          // This closes the fence
          return false
        }
      }
    }
    
    // If not a closing fence, the block continues
    return true
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    // Work directly with tokens - skip leading whitespace
    var tokenIndex = 0
    while tokenIndex < line.tokens.count && line.tokens[tokenIndex].element == .whitespaces {
      tokenIndex += 1
    }
    
    guard tokenIndex < line.tokens.count else { return nil }
    
    let (isFence, fenceChar, fenceLength) = checkFencePattern(tokens: line.tokens, startIndex: tokenIndex)
    guard isFence && fenceLength >= 3 else { return nil }
    
    // Calculate indentation properties
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: line.tokens)
    let fenceColumn = leadingSpaces  // For now, assume fence starts after leading whitespace
    
    // Skip past the fence tokens
    tokenIndex += fenceLength
    
    // Extract info string from remaining tokens
    var language: String? = nil
    var infoStringParts: [String] = []
    
    while tokenIndex < line.tokens.count {
      let token = line.tokens[tokenIndex]
      if token.element == .newline || token.element == .eof {
        break
      }
      if token.element != .whitespaces || !infoStringParts.isEmpty {
        infoStringParts.append(token.text)
      }
      tokenIndex += 1
    }
    
    if !infoStringParts.isEmpty {
      let infoString = infoStringParts.joined().trimmingCharacters(in: .whitespaces)
      language = infoString.split(separator: " ").first.map(String.init)
    }
    
    let codeBlock = MarkdownFencedCodeBlock(
      fenceChar: fenceChar,
      fenceLength: fenceLength,
      language: language
    )
    
    // Set package-level indentation properties
    codeBlock.indent = leadingSpaces
    codeBlock.fenceIndent = leadingSpaces
    codeBlock.fenceColumn = fenceColumn
    
    return codeBlock
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine, state: inout MarkdownConstructState) -> Bool {
    guard let codeBlock = block as? MarkdownFencedCodeBlock else { return false }
    
    // Check if this is a closing fence
    if !canContinue(block: block, line: line) {
      // This is a closing fence, don't add it to content
      codeBlock.isClosed = true
      return true
    }
    
    // Remove up to the fence indentation from the content line
    let contentTokens = MarkdownIndentation.removeIndentation(from: line.tokens, upToColumn: codeBlock.fenceIndent)
    
    // Convert tokens to content
    var contentParts: [String] = []
    for token in contentTokens {
      if token.element == .newline || token.element == .eof {
        break
      }
      contentParts.append(token.text)
    }
    let content = contentParts.joined()
    
    if !codeBlock.source.isEmpty {
      codeBlock.source += "\n"
    }
    codeBlock.source += content
    
    return true
  }
  
  /// Check if tokens form a fence pattern starting at given index
  /// Returns (isFence, fenceChar, fenceLength)
  private func checkFencePattern(tokens: [any CodeToken<MarkdownTokenElement>], startIndex: Int) -> (Bool, Character, Int) {
    guard startIndex < tokens.count else { return (false, " ", 0) }
    
    let firstToken = tokens[startIndex]
    guard firstToken.element == .punctuation else { return (false, " ", 0) }
    
    // Check for backtick or tilde fence - each character is a separate token
    let firstChar = firstToken.text.first
    guard firstChar == "`" || firstChar == "~" else { return (false, " ", 0) }
    
    // Count consecutive fence characters
    var fenceLength = 0
    var index = startIndex
    
    while index < tokens.count {
      let token = tokens[index]
      if token.element == .punctuation && token.text.first == firstChar {
        fenceLength += 1
        index += 1
      } else {
        break
      }
    }
    
    return (fenceLength >= 3, firstChar!, fenceLength)
  }
}

/// Specialized code block for fenced code blocks
public class MarkdownFencedCodeBlock: CodeBlockNode {
  public override var blockType: String { "fenced_code_block" }
  public var fenceChar: Character
  public var fenceLength: Int
  public var isClosed: Bool = false
  
  // Package-level properties for enhanced nested block parsing
  package var fenceIndent: Int = 0  // Number of spaces before the opening fence
  package var fenceColumn: Int = 0  // Column position of the opening fence
  
  public init(fenceChar: Character, fenceLength: Int, language: String? = nil) {
    self.fenceChar = fenceChar
    self.fenceLength = fenceLength
    // Use empty source initially, will be populated during processing
    super.init(source: "", language: language)
  }
  
  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(fenceChar)
    hasher.combine(fenceLength)
  }
}
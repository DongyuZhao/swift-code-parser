import CodeParserCore
import Foundation

/// Builder for fenced code blocks (```code``` or ~~~code~~~)
/// Implements CommonMark specification for fenced code blocks (Spec 018)
public class MarkdownFencedCodeBlockBuilder: MarkdownBlockBuilderProtocol {
  
  public init() {}
  
  public func canStart(line: MarkdownLine) -> Bool {
    // Fenced code blocks can be indented 0-3 spaces
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces > 3 {
      return false
    }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    
    // Must start with at least 3 backticks (`) or tildes (~)
    if content.hasPrefix("```") || content.hasPrefix("~~~") {
      let fenceChar = content.first!
      let fenceLength = content.prefix { $0 == fenceChar }.count
      
      if fenceLength >= 3 {
        // Check that the rest of the line only contains valid info string
        let afterFence = content.dropFirst(fenceLength)
        
        // For backticks, info string cannot contain backticks
        if fenceChar == "`" && afterFence.contains("`") {
          return false
        }
        
        return true
      }
    }
    
    return false
  }
  
  public func canContinue(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let codeBlock = block as? MarkdownFencedCodeBlock,
          block.blockType == "fenced_code_block" else { return false }
    
    // Check if this line closes the fence
    let leadingSpaces = line.leadingWhitespace
    if leadingSpaces <= 3 {
      let content = line.content.trimmingCharacters(in: .whitespaces)
      
      if content.hasPrefix(String(codeBlock.fenceChar)) {
        let fenceLength = content.prefix { $0 == codeBlock.fenceChar }.count
        
        // Closing fence must be at least as long as opening fence
        if fenceLength >= codeBlock.fenceLength {
          // Check that the rest of the line only contains spaces
          let afterFence = content.dropFirst(fenceLength)
          if afterFence.allSatisfy({ $0 == " " || $0 == "\t" }) {
            // This closes the fence
            return false
          }
        }
      }
    }
    
    // If not a closing fence, the block continues
    return true
  }
  
  public func createBlock(from line: MarkdownLine) -> (any MarkdownBlockNode)? {
    guard canStart(line: line) else { return nil }
    
    let content = line.content.trimmingCharacters(in: .whitespaces)
    let fenceChar = content.first!
    let fenceLength = content.prefix { $0 == fenceChar }.count
    
    // Extract info string
    let afterFence = String(content.dropFirst(fenceLength)).trimmingCharacters(in: .whitespaces)
    let language = afterFence.isEmpty ? nil : String(afterFence.split(separator: " ").first ?? "")
    
    let codeBlock = MarkdownFencedCodeBlock(
      fenceChar: fenceChar,
      fenceLength: fenceLength,
      language: language
    )
    
    return codeBlock
  }
  
  public func processLine(block: any MarkdownBlockNode, line: MarkdownLine) -> Bool {
    guard let codeBlock = block as? MarkdownFencedCodeBlock else { return false }
    
    // Check if this is a closing fence
    if !canContinue(block: block, line: line) {
      // This is a closing fence, don't add it to content
      codeBlock.isClosed = true
      return true
    }
    
    // Add line content to the code block
    let content = line.content
    if !codeBlock.source.isEmpty {
      codeBlock.source += "\n"
    }
    codeBlock.source += content
    
    return true
  }
}

/// Specialized code block for fenced code blocks
public class MarkdownFencedCodeBlock: MarkdownNodeBase, MarkdownBlockNode {
  public var blockType: String { "fenced_code_block" }
  public var fenceChar: Character
  public var fenceLength: Int
  public var language: String?
  public var source: String = ""
  public var isClosed: Bool = false
  
  public init(fenceChar: Character, fenceLength: Int, language: String? = nil) {
    self.fenceChar = fenceChar
    self.fenceLength = fenceLength
    self.language = language
    super.init(element: .codeBlock)
  }
  
  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(fenceChar)
    hasher.combine(fenceLength)
    hasher.combine(language)
    hasher.combine(source)
  }
}
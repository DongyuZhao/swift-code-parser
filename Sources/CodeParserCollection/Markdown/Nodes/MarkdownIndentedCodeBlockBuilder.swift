import CodeParserCore
import Foundation

/// Handles indented code blocks (4+ spaces or 1+ tabs)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#indented-code-blocks
public class MarkdownIndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check for indentation at start of line (4 spaces or 1 tab minimum)
    var index = startIndex
    var indentationSpaces = 0
    
    while index < context.tokens.count {
      let token = context.tokens[index]
      
      if token.element == .whitespaces {
        // Count spaces and tabs (tab = 4 spaces for indentation)
        for char in token.text {
          switch char {
          case " ":
            indentationSpaces += 1
          case "\t":
            indentationSpaces += 4
          default:
            break
          }
        }
        index += 1
      } else {
        // Found non-whitespace, stop counting indentation
        break
      }
    }
    
    // Must have at least 4 spaces of indentation for code block
    guard indentationSpaces >= 4 else {
      return false
    }
    
    // If we reached end of tokens, this is just indented whitespace - not a code block
    guard index < context.tokens.count else {
      return false
    }
    
    // Find the end of content for this line (excluding newline)
    var contentEnd = context.tokens.count
    for i in index..<context.tokens.count {
      if context.tokens[i].element == .newline {
        contentEnd = i
        break
      }
    }
    
    // Extract the code content (removing exactly 4 spaces of indentation)
    let codeTokens = Array(context.tokens[startIndex..<contentEnd])
    var codeContent = ""
    var remainingSpacesToRemove = 4
    
    for token in codeTokens {
      if token.element == .whitespaces && remainingSpacesToRemove > 0 {
        // Remove indentation spaces
        var processedText = ""
        for char in token.text {
          if remainingSpacesToRemove > 0 {
            switch char {
            case " ":
              remainingSpacesToRemove -= 1
            case "\t":
              // Remove up to remaining spaces from tab
              let tabSpacesToRemove = min(remainingSpacesToRemove, 4)
              remainingSpacesToRemove -= tabSpacesToRemove
              // If tab has leftover spaces, add them
              if tabSpacesToRemove < 4 {
                processedText += String(repeating: " ", count: 4 - tabSpacesToRemove)
              }
            default:
              processedText.append(char)
            }
          } else {
            processedText.append(char)
          }
        }
        codeContent += processedText
      } else {
        // Add all other content as-is
        switch token.element {
        case .characters, .punctuation:
          codeContent += token.text
        case .whitespaces:
          codeContent += token.text
        case .charef:
          codeContent += token.text
        default:
          break
        }
      }
    }
    
    // Check if we can continue an existing code block or need to create a new one
    if let lastChild = context.current.children.last as? CodeBlockNode,
       lastChild.language == nil { // Only continue unlabeled code blocks
      // Add newline and continue existing code block
      lastChild.source += "\n" + codeContent
    } else {
      // Create new indented code block
      let codeBlock = CodeBlockNode(source: codeContent)
      context.current.append(codeBlock)
    }

    return true
  }
}
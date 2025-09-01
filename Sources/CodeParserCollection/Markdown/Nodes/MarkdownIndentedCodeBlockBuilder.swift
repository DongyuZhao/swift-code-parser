import CodeParserCore
import Foundation

/// Handles indented code blocks (4+ spaces or 1+ tabs)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#indented-code-blocks
public class MarkdownIndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
  guard context.state is MarkdownConstructState else {
      return false
    }

  // In phased pipeline, builders receive the suffix tokens; always start at local 0
  let startIndex = 0
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

    // Check if this is a blank line that could be part of a code block
    let isBlankLine = index >= context.tokens.count || context.tokens[index].element == .newline

    // If this is a blank line, check if we can continue an existing code block
    if isBlankLine {
      if let lastChild = context.current.children.last as? CodeBlockNode,
         lastChild.language == nil { // Only continue unlabeled code blocks
        // Add blank line to existing code block
        lastChild.source += "\n"
        return true
      } else {
        // No existing code block to continue, let other builders handle
        return false
      }
    }

    // Must have at least 4 spaces of indentation for code block
    guard indentationSpaces >= 4 else {
      return false
    }

    // Indented code blocks cannot interrupt paragraphs
    if context.current.element == .paragraph {
      return false
    }
    
    // Check if we're in a list item context - indented content should be treated as list continuation
    // rather than code block if the indentation matches list item requirements
    if let listItem = findContainingListItem(context.current) {
      // If the indentation is exactly what's needed for list item continuation,
      // don't create a code block - let list continuation handle it
      if indentationSpaces < listItem.contentIndent + 4 {
        return false
      }
    }

    // If we reached end of tokens, this is just indented whitespace - not a code block
    guard index < context.tokens.count else {
      return false
    }

    // Extract the code content including newline (removing exactly 4 spaces of indentation)
    let codeTokens = Array(context.tokens[startIndex...])
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
        // Add all other content as-is including newlines
        switch token.element {
        case .characters, .punctuation, .whitespaces, .charef, .newline:
          codeContent += token.text
        default:
          break
        }
      }
    }

    // Check if we can continue an existing code block or need to create a new one
    if let lastChild = context.current.children.last as? CodeBlockNode,
       lastChild.language == nil { // Only continue unlabeled code blocks
      // Continue existing code block (codeContent already includes newline)
      lastChild.source += codeContent
    } else {
      // Create new indented code block
      let codeBlock = CodeBlockNode(source: codeContent)
      context.current.append(codeBlock)
    }

    return true
  }

  private func findContainingListItem(_ node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
    var current: CodeNode<MarkdownNodeElement>? = node
    while let n = current {
      if let listItem = n as? ListItemNode {
        return listItem
      }
      current = n.parent
    }
    return nil
  }
}
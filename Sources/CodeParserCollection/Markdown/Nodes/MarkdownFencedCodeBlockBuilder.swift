import CodeParserCore
import Foundation

/// Handles fenced code blocks with ``` or ~~~ delimiters
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#fenced-code-blocks
public class MarkdownFencedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    let startIndex = 0
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check if we're currently inside a fenced code block
    if let currentFence = state.openFence {
      // If we're at position 0 and the line starts with block-level markers,
      // let other builders process first
      if state.position == 0 && startIndex < context.tokens.count {
        let token = context.tokens[startIndex]
        if token.element == .punctuation && (token.text == ">" || token.text == "#" || token.text == "*" || token.text == "-" || token.text == "+") {
          return false
        }
      }
      return handleFencedContent(currentFence: currentFence, context: &context, state: state)
    } else {
      return handleFenceOpening(context: &context, state: state, startIndex: startIndex)
    }
  }

  private func handleFenceOpening(
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState,
    startIndex: Int
  ) -> Bool {
    var index = startIndex
    
    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < context.tokens.count,
          let token = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      let spaceCount = token.text.count
      if leadingSpaces + spaceCount > 3 {
        return false
      }
      leadingSpaces += spaceCount
      index += 1
    }

    // Check for fence characters
    guard index < context.tokens.count else { return false }
    
    let fenceChar: String
    if let firstToken = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
       firstToken.element == .punctuation {
      switch firstToken.text {
      case "`", "~":
        fenceChar = firstToken.text
      default:
        return false
      }
    } else {
      return false
    }

    // Count consecutive fence characters (must be at least 3)
    var fenceLength = 0
    while index < context.tokens.count,
          let token = context.tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == fenceChar {
      fenceLength += 1
      index += 1
    }

    guard fenceLength >= 3 else {
      return false
    }

    // Save the starting position after the opening fence for later checking
    let afterOpeningFenceIndex = index
    
    // Extract info string (language specification) after the fence
    var infoString = ""
    var foundNonWhitespace = false
    
    while index < context.tokens.count {
      let token = context.tokens[index]
      
      if token.element == .newline {
        break
      } else if token.element == .whitespaces {
        if foundNonWhitespace {
          infoString += token.text
        }
        index += 1
      } else {
        foundNonWhitespace = true
        infoString += token.text
        index += 1
      }
    }

    // Trim trailing whitespace from info string
    infoString = infoString.trimmingCharacters(in: .whitespaces)

    // Check if there's a closing fence on the same line
    // According to CommonMark spec, a fenced code block cannot have opening and closing fence on the same line
    // The key insight is: we should only consider fence characters that appear AFTER the info string has been fully parsed
    // Since we already extracted the info string above, any fence characters we find are potential closing fences
    
    // However, we need to be careful: info strings can contain fence characters of the OTHER type
    // For backtick fences, info string cannot contain backticks
    // For tilde fences, info string CAN contain both backticks and tildes
    
    // The issue is that once we've tokenized, we can't distinguish between:
    // 1. `~~~ content ~~~` (same-line fence - should be inline code)  
    // 2. `~~~ info ~~~` where the second ~~~ is part of info string (should be fenced code block)
    
    // The correct approach: Only apply same-line detection for backtick fences
    // since backtick info strings cannot contain backticks, so any backticks found are closing fences
    
    if fenceChar == "`" {
      // For backtick fences, info string cannot contain backticks, so any backticks are closing fences
      for checkIndex in afterOpeningFenceIndex..<index {
        let token = context.tokens[checkIndex]
        
        if token.element == .punctuation && token.text == fenceChar {
          // Found potential start of closing fence on same line - check if it's valid
          var closingFenceLength = 0
          var closingIndex = checkIndex
          
          // Count consecutive fence characters
          while closingIndex < index,
                closingIndex < context.tokens.count,
                let closingToken = context.tokens[closingIndex] as? any CodeToken<MarkdownTokenElement>,
                closingToken.element == .punctuation,
                closingToken.text == fenceChar {
            closingFenceLength += 1
            closingIndex += 1
          }
          
          // Check if this is a valid closing fence (at least as long as opening fence)
          if closingFenceLength >= fenceLength {
            // Check if rest of line is whitespace only or end of line
            var isValidClosing = true
            var remainingIndex = closingIndex
            
            while remainingIndex < index {
              let remainingToken = context.tokens[remainingIndex]
              if remainingToken.element != .whitespaces {
                isValidClosing = false
                break
              }
              remainingIndex += 1
            }
            
            if isValidClosing {
              // Valid closing fence found on same line - this is not a fenced code block
              return false
            }
          }
        }
      }
    }
    // For tilde fences, do NOT check for same-line closing since tildes can appear in info string

    // Fenced code blocks can interrupt paragraphs - close paragraph if we're in one
    if context.current.element == .paragraph {
      if let parent = context.current.parent {
        context.current = parent
      }
    }

    // Create fenced code block
    let language = infoString.isEmpty ? nil : infoString.components(separatedBy: .whitespaces).first
    let codeBlock = CodeBlockNode(source: "", language: language)
    context.current.append(codeBlock)

    // Store the open fence info for subsequent lines
    state.openFence = OpenFenceInfo(
      character: fenceChar,
      length: fenceLength,
      indentation: leadingSpaces,
      codeBlock: codeBlock
    )

    return true
  }

  private func handleFencedContent(
    currentFence: OpenFenceInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = 0

    // Check if this line is a closing fence
    if let closingFenceLength = checkClosingFence(
      character: currentFence.character,
      minLength: currentFence.length,
      tokens: context.tokens,
      startIndex: startIndex
    ) {
      // This is a closing fence - close the code block
      state.openFence = nil
      return true
    }

    // If we're at position 0, check if this line belongs to the same container context
    // If not, close the fenced code block and let other builders handle the line
    if state.position == 0 && startIndex < context.tokens.count {
      let token = context.tokens[startIndex]
      if token.element == .punctuation && (token.text == ">" || token.text == "#" || token.text == "*" || token.text == "-" || token.text == "+") {
        // This line has block-level markers, let other builders process first
        return false
      }
      // For empty lines at position 0, check if we're in a container context that should be closed
      if token.element == .newline {
        // Only close fenced code block if we're in a container context (like blockquote)
        // and this empty line should close that container
        if context.current.element == .blockquote {
          // Empty line in blockquote context - this should close the blockquote
          state.openFence = nil
          return false
        }
        // For other contexts (like document level), empty lines are content
      }
    }

    // This is content - add it to the code block
    var lineContent = ""
    var index = startIndex

    // Include everything in this line, including newline
    var contentEnd = context.tokens.count

    // Remove equivalent indentation from this line
    var remainingIndentationToRemove = currentFence.indentation
    
    // Skip leading whitespace up to the fence's indentation level
    while index < contentEnd && remainingIndentationToRemove > 0 {
      let token = context.tokens[index]
      if token.element == .whitespaces {
        let spaceCount = token.text.count
        if spaceCount <= remainingIndentationToRemove {
          // Skip this entire whitespace token
          remainingIndentationToRemove -= spaceCount
          index += 1
        } else {
          // Partially use this whitespace token
          let remainingSpaces = spaceCount - remainingIndentationToRemove
          lineContent += String(repeating: " ", count: remainingSpaces)
          remainingIndentationToRemove = 0
          index += 1
        }
      } else {
        // Non-whitespace token, stop indentation removal
        break
      }
    }

    // Extract remaining content tokens including newline
    while index < contentEnd {
      let token = context.tokens[index]
      switch token.element {
      case .characters, .punctuation, .whitespaces, .charef, .newline:
        lineContent += token.text
      default:
        break
      }
      index += 1
    }

    // Add content to the code block (lineContent already includes newline)
    currentFence.codeBlock.source += lineContent

    return true
  }

  private func checkClosingFence(
    character: String,
    minLength: Int,
    tokens: [any CodeToken<MarkdownTokenElement>],
    startIndex: Int
  ) -> Int? {
    var index = startIndex

    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < tokens.count,
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      let spaceCount = token.text.count
      if leadingSpaces + spaceCount > 3 {
        return nil
      }
      leadingSpaces += spaceCount
      index += 1
    }

    // Count fence characters
    var fenceLength = 0
    while index < tokens.count,
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == character {
      fenceLength += 1
      index += 1
    }

    // Must have at least as many characters as opening fence
    guard fenceLength >= minLength else {
      return nil
    }

    // Skip remaining whitespace until end of line
    while index < tokens.count,
          let token = tokens[index] as? any CodeToken<MarkdownTokenElement>,
          token.element == .whitespaces {
      index += 1
    }

    // Must reach end of line or newline
    if index < tokens.count {
      let token = tokens[index]
      if token.element != .newline {
        return nil
      }
    }

    return fenceLength
  }
}
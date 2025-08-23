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

    let startIndex = state.position
    guard startIndex < context.tokens.count else {
      return false
    }

    // Check if we're currently inside a fenced code block
    if let currentFence = state.openFence {
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

    // Create fenced code block
    let language = infoString.isEmpty ? nil : infoString.components(separatedBy: .whitespaces).first
    let codeBlock = CodeBlockNode(source: "", language: language)
    context.current.append(codeBlock)

    // Store the open fence info for subsequent lines
    state.openFence = OpenFenceInfo(
      character: fenceChar,
      length: fenceLength,
      codeBlock: codeBlock
    )

    return true
  }

  private func handleFencedContent(
    currentFence: OpenFenceInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = state.position

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

    // This is content - add it to the code block
    var lineContent = ""
    var index = startIndex

    // Find the end of this line (before newline)
    var contentEnd = context.tokens.count
    for i in startIndex..<context.tokens.count {
      if context.tokens[i].element == .newline {
        contentEnd = i
        break
      }
    }

    // Extract content tokens
    while index < contentEnd {
      let token = context.tokens[index]
      switch token.element {
      case .characters, .punctuation:
        lineContent += token.text
      case .whitespaces:
        lineContent += token.text
      case .charef:
        lineContent += token.text
      default:
        break
      }
      index += 1
    }

    // Add content to the code block
    if currentFence.codeBlock.source.isEmpty {
      currentFence.codeBlock.source = lineContent
    } else {
      currentFence.codeBlock.source += "\n" + lineContent
    }

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
import CodeParserCore
import Foundation

/// Processes code spans (`code`)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#code-spans
public class MarkdownCodeSpanProcessor: MarkdownContentProcessor {
  public let delimiters: Set<Character> = ["`"]

  public init() {}

  public func process(
    _ token: any CodeToken<MarkdownTokenElement>,
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> Bool {
    guard token.element == .punctuation,
          token.text == "`" else {
      return false
    }

    // Count consecutive opening backticks
    let openingInfo = countBackticks(startingAt: index, in: tokens)
    guard openingInfo.count > 0 else { return false }
    
    // Look for matching closing backticks
    guard let closingInfo = findClosingBackticks(
      afterIndex: index + openingInfo.count - 1,
      withCount: openingInfo.count,
      in: tokens
    ) else {
      // No matching closing backticks - treat as regular text
      return false
    }
    
    // Extract code content between opening and closing backticks
    let contentStart = index + openingInfo.count
    let contentEnd = closingInfo.startIndex
    
    var codeContent = ""
    for i in contentStart..<contentEnd {
      let contentToken = tokens[i]
      switch contentToken.element {
      case .characters, .punctuation:
        codeContent += contentToken.text
      case .whitespaces:
        // Preserve whitespace in code spans
        codeContent += contentToken.text
      case .newline:
        // Convert newlines to single spaces in code spans
        codeContent += " "
      case .charef:
        // Character references are not processed in code spans
        codeContent += contentToken.text
      case .hardbreak:
        // Hard breaks become spaces in code spans
        codeContent += " "
      case .eof:
        break
      }
    }
    
    // Strip one space from each side if both sides have spaces and content is not just spaces
    if codeContent.hasPrefix(" ") && codeContent.hasSuffix(" ") && codeContent.count > 2 {
      let trimmed = String(codeContent.dropFirst().dropLast())
      if !trimmed.trimmingCharacters(in: .whitespaces).isEmpty {
        codeContent = trimmed
      }
    }
    
    // Create code span node
    let codeSpan = CodeSpanNode(code: codeContent)
    context.add(codeSpan)
    
    // Advance past all consumed tokens
    let totalTokensConsumed = closingInfo.startIndex + closingInfo.count - index
    context.advance(by: totalTokensConsumed - 1)
    
    return true
  }

  public func finalize(context: inout MarkdownContentContext) {
    // Code spans don't need finalization
  }
  
  private func countBackticks(
    startingAt index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (count: Int, endIndex: Int) {
    var count = 0
    var currentIndex = index
    
    while currentIndex < tokens.count,
          let token = tokens[currentIndex] as? any CodeToken<MarkdownTokenElement>,
          token.element == .punctuation,
          token.text == "`" {
      count += 1
      currentIndex += 1
    }
    
    return (count: count, endIndex: currentIndex)
  }
  
  private func findClosingBackticks(
    afterIndex startIndex: Int,
    withCount targetCount: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (startIndex: Int, count: Int)? {
    var index = startIndex + 1
    
    while index < tokens.count {
      let token = tokens[index]
      
      if token.element == .punctuation && token.text == "`" {
        // Found potential closing backticks
        let backticksInfo = countBackticks(startingAt: index, in: tokens)
        
        if backticksInfo.count == targetCount {
          // Found matching closing backticks
          return (startIndex: index, count: backticksInfo.count)
        }
        
        // Skip over this backtick sequence and continue looking
        index = backticksInfo.endIndex
      } else {
        index += 1
      }
    }
    
    return nil
  }
}
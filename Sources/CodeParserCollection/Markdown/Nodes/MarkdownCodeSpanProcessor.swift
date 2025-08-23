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
    guard token.element == .punctuation, token.text == "`" else { return false }

    // Aggregate consecutive backticks into a run and push to delimiter stack.
    let openingInfo = countBackticks(startingAt: index, in: tokens)
    guard openingInfo.count > 0 else { return false }

    let run = MarkdownDelimiterRun(
      type: .backtick(count: openingInfo.count),
      length: openingInfo.count,
      openable: true,
      closable: true,
      index: context.current
    )
    context.delimiters.push(run, textNode: nil)

    // Advance by the full run length; pairing will be done in builder finalize phase
    context.advance(by: openingInfo.count)
    return true
  }

  public func createNode(
    for delimiterType: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>
  ) -> MarkdownNodeBase? {
    // Only handle backtick code spans
    guard case .backtick(let openerCount) = openerRun.delimiter,
          case .backtick(let closerCount) = closerRun.delimiter,
          openerCount == closerCount else {
      return nil
    }

    // Build literal code content from tokens
    var codeContent = ""
    for token in contentTokens {
      switch token.element {
      case .characters, .punctuation:
        codeContent += token.text
      case .whitespaces:
        codeContent += token.text
      case .newline:
        codeContent += " "
      case .charef:
        codeContent += token.text
      case .eof:
        break
      }
    }

    // Strip one leading and trailing space if both sides have space and content isn't all spaces
    if codeContent.hasPrefix(" ") && codeContent.hasSuffix(" ") && codeContent.count > 2 {
      let inner = String(codeContent.dropFirst().dropLast())
      if !inner.trimmingCharacters(in: .whitespaces).isEmpty {
        codeContent = inner
      }
    }

    return CodeSpanNode(code: codeContent)
  }

  // Processor capabilities
  public func supports(delimiter: MarkdownDelimiter) -> Bool {
    if case .backtick = delimiter { return true }
    return false
  }

  public func canPair(opener: MarkdownDelimiterRun, closer: MarkdownDelimiterRun, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    guard case .backtick(let o) = opener.delimiter, case .backtick(let c) = closer.delimiter else { return false }
    return o == c
  }

  private func countBackticks(
    startingAt index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (count: Int, endIndex: Int) {
    var count = 0
    var currentIndex = index

    while currentIndex < tokens.count,
          tokens[currentIndex].element == .punctuation,
          tokens[currentIndex].text == "`" {
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
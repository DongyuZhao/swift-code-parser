import CodeParserCore
import Foundation

/// Handles Setext headings (underline style with = and -)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#setext-headings
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else {
      return false
    }

    // Check if this line is a setext underline
    guard let underlineInfo = checkSetextUnderline(tokens: context.tokens, startIndex: 0) else {
      return false
    }

    // Look for a preceding paragraph to convert
    let targetParagraph: CodeNode<MarkdownNodeElement>
    let parentContext: CodeNode<MarkdownNodeElement>
    
    if context.current.element == .paragraph {
      // We're in leafOnLine phase, and the current paragraph contains the content that should become a heading
      // The underline line is about to be added to this paragraph, but instead we should convert the paragraph to a heading
      
      // Important: Check if this paragraph actually has content that's NOT the underline itself
      // We need to distinguish between:
      // 1. A paragraph with real content (e.g., "Foo") + underline -> valid setext heading
      // 2. A paragraph that only contains the underline tokens -> not a valid setext heading
      
      // Check if the paragraph has content that's not just the current underline tokens
      let hasNonUnderlineContent = context.current.children.contains { child in
        if let contentNode = child as? ContentNode {
          // Check if this content node contains anything other than the current underline
          return !isOnlyUnderlineTokens(contentNode.tokens, underlineInfo: underlineInfo)
        }
        return true // Non-content nodes count as content
      }
      
      if !hasNonUnderlineContent {
        // This paragraph only contains the underline tokens - not a valid setext heading
        return false
      }
      
      targetParagraph = context.current
      guard let parent = context.current.parent else {
        return false
      }
      parentContext = parent
    } else {
      // We're likely in postParagraph phase, at document level
      // Look for the last child that's a paragraph, or a thematic break that could be converted to a setext heading
      
      if let lastChild = context.current.children.last, lastChild.element == .paragraph {
        // Case 1: Last child is a paragraph (for "=" underlines that weren't processed by thematic break builder)
        // Must have content to form a valid setext heading
        if lastChild.children.isEmpty {
          return false
        }
        targetParagraph = lastChild
        parentContext = context.current
      } else if context.current.children.count >= 2,
                let lastChild = context.current.children.last,
                lastChild.element == .thematicBreak {
        // Case 2: Last child is a thematic break, second-to-last is a paragraph
        // This happens when "---------" was processed as a thematic break but should be a setext heading
        
        let secondLastChild = context.current.children[context.current.children.count - 2]
        guard secondLastChild.element == .paragraph else {
          return false
        }
        
        // Must have content to form a valid setext heading
        if secondLastChild.children.isEmpty {
          return false
        }
        
        // IMPORTANT: Check if there was a blank line between the paragraph and thematic break
        // If there was a blank line, this should remain a thematic break, not become a setext heading
        // We can detect this by checking if the paragraph and thematic break are in adjacent positions
        // but were created in separate parsing contexts (indicating a blank line separation)
        
        // For now, be conservative and only convert in very specific cases
        // TODO: Add proper blank line detection using state.lastWasBlankLine or other mechanisms
        
        // Check if the thematic break could be a setext underline (only "-" can be both)
        if underlineInfo.level == 2 { // Only level 2 (dash) can conflict with thematic breaks
          // Check if there was a blank line between the paragraph and thematic break
          // We can do this by examining the paragraph content and seeing if it ends with
          // content that would indicate it was closed by a blank line
          
          // For now, use a heuristic: if the paragraph contains newline tokens that would
          // suggest it was a multi-line paragraph, but check more carefully later
          
          // TODO: Implement proper blank line detection using state.lastWasBlankLine
          // For now, allow this conversion but be aware it might need refinement
          
          // Remove the thematic break and convert the paragraph to a heading
          lastChild.remove()
          targetParagraph = secondLastChild
          parentContext = context.current
        } else {
          return false
        }
      } else {
        return false
      }
    }

    // Check if we're inside a container where setext headings cannot be formed
    // According to CommonMark spec, setext heading underlines cannot be lazy continuation lines in blockquotes or list items
    if isInsideContainer(context: context, checkingNode: targetParagraph) {
      // We're inside a container - the underline should be treated as lazy continuation text
      // or as a thematic break, not as a setext heading underline
      return false
    }

    // Convert the paragraph to a heading
    let heading = HeaderNode(level: underlineInfo.level)

    // Move all children from paragraph to heading, excluding any content that's just the underline
    for child in targetParagraph.children {
      if let contentNode = child as? ContentNode {
        // Remove underline tokens from the content if they're at the end
        let cleanedTokens = removeTrailingUnderlineTokens(contentNode.tokens, underlineInfo: underlineInfo)
        if !cleanedTokens.isEmpty {
          // Create new content node with cleaned tokens
          let cleanedContent = ContentNode(tokens: cleanedTokens)
          heading.append(cleanedContent)
        }
      } else {
        // Non-content nodes - move as-is
        child.remove()
        heading.append(child)
      }
    }

    // Replace paragraph with heading
    let insertIndex = parentContext.children.firstIndex { $0 === targetParagraph } ?? (parentContext.children.count - 1)
    targetParagraph.remove()
    parentContext.insert(heading, at: insertIndex)

    // Update context if needed
    if context.current === targetParagraph {
      context.current = parentContext
    }

    return true
  }
  
  // Check if tokens only contain underline characters (=== or ---)
  private func isOnlyUnderlineTokens(
    _ tokens: [any CodeToken<MarkdownTokenElement>], 
    underlineInfo: (level: Int, endIndex: Int)
  ) -> Bool {
    let underlineChar = underlineInfo.level == 1 ? "=" : "-"
    
    for token in tokens {
      switch token.element {
      case .whitespaces, .newline:
        continue // Skip whitespace and newlines
      case .punctuation:
        if token.text == underlineChar {
          continue // Skip underline characters
        }
        return false // Other punctuation means it's not just underline
      default:
        return false // Any other token means it's not just underline
      }
    }
    return true
  }
  
  // Remove trailing underline tokens from a token array
  private func removeTrailingUnderlineTokens(
    _ tokens: [any CodeToken<MarkdownTokenElement>], 
    underlineInfo: (level: Int, endIndex: Int)
  ) -> [any CodeToken<MarkdownTokenElement>] {
    let underlineChar = underlineInfo.level == 1 ? "=" : "-"
    var result = tokens
    
    // Remove trailing newlines and underline characters
    while let last = result.last {
      if last.element == .newline || 
         (last.element == .punctuation && last.text == underlineChar) ||
         (last.element == .whitespaces) {
        result.removeLast()
      } else {
        break
      }
    }
    
    return result
  }

  private func isInsideContainer(context: CodeConstructContext<Node, Token>, checkingNode: CodeNode<MarkdownNodeElement>) -> Bool {
    // Walk up the hierarchy from the node being checked to see if it's inside a container
    var current: MarkdownNodeBase? = checkingNode.parent as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode || node is ListItemNode {
        return true
      }
      current = node.parent as? MarkdownNodeBase
    }
    return false
  }

  private func checkSetextUnderline(
    tokens: [any CodeToken<MarkdownTokenElement>],
    startIndex: Int
  ) -> (level: Int, endIndex: Int)? {
    var index = startIndex

    // Skip leading whitespace (up to 3 spaces allowed)
    var leadingSpaces = 0
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      let spaceCount = tokens[index].text.count
      if leadingSpaces + spaceCount > 3 {
        return nil
      }
      leadingSpaces += spaceCount
      index += 1
    }

    // Must have at least one underline character
    guard index < tokens.count else {
      return nil
    }

    // Determine underline character and level
    let underlineChar: String
    let level: Int

    if tokens[index].element == .punctuation {
      switch tokens[index].text {
      case "=":
        underlineChar = "="
        level = 1
      case "-":
        underlineChar = "-"
        level = 2
      default:
        return nil
      }
    } else {
      return nil
    }

    // Count consecutive underline characters (must be at least 1)
    var underlineCount = 0
    while index < tokens.count,
          tokens[index].element == .punctuation,
          tokens[index].text == underlineChar {
      underlineCount += 1
      index += 1
    }

    guard underlineCount >= 1 else { return nil }

    // Skip trailing whitespace
    while index < tokens.count,
          tokens[index].element == .whitespaces {
      index += 1
    }

    // Must be at end of line (or have newline)
    if index < tokens.count {
      if tokens[index].element != .newline {
        return nil
      }
    }

    return (level: level, endIndex: index)
  }
}
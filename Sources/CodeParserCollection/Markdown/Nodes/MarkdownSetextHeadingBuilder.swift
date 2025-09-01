import CodeParserCore
import Foundation

/// Handles Setext headings (underline style with = and -)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#setext-headings
public class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.state is MarkdownConstructState else {
      return false
    }

    // Check if this line is a setext underline
    guard let underlineInfo = checkSetextUnderline(tokens: context.tokens, startIndex: 0) else {
      return false
    }

    // Look for a preceding paragraph to convert
    // The logic differs based on the current context:
    // - If we're in a paragraph context, we need to convert the current paragraph to a heading
    // - If we're at document level, we need to look at the last child
    
    let targetParagraph: CodeNode<MarkdownNodeElement>
    let parentContext: CodeNode<MarkdownNodeElement>
    
    if context.current.element == .paragraph {
      // We're in leafOnLine phase, and the current paragraph contains the content that should become a heading
      // The "=========" line is about to be added to this paragraph, but instead we should convert the paragraph to a heading
      
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
        
        // Check if the thematic break could be a setext underline (only "-" can be both)
        if underlineInfo.level == 2 { // Only level 2 (dash) can conflict with thematic breaks
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

    // Move all children from paragraph to heading
    while let child = targetParagraph.children.first {
      child.remove()
      heading.append(child)
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
import CodeParserCore
import Foundation

public class MarkdownContentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Traverse the AST to parse all the content nodes
    var foundContentNodes = 0
    context.root.dfs { node in
      if let node = node as? ContentNode {
        foundContentNodes += 1
        print("DEBUG: Found ContentNode with \(node.tokens.count) tokens:")
        for (i, token) in node.tokens.enumerated() {
          print("  Token \(i): \(token.element) = '\(token.text)'")
        }
        process(node)
      }
    }
    print("DEBUG: ContentBuilder processed \(foundContentNodes) ContentNodes")
    return true
  }

  // Delimiter stack based inline processing following CommonMark spec
  private func process(_ node: ContentNode) {
    let processor = InlineProcessor(tokens: node.tokens)
    let inlineNodes = processor.process()
    
    print("DEBUG: InlineProcessor produced \(inlineNodes.count) nodes:")
    for (i, inlineNode) in inlineNodes.enumerated() {
      print("  Node \(i): \(inlineNode.element)")
      if let textNode = inlineNode as? TextNode {
        print("    TextNode content: '\(textNode.content)'")
      }
    }
    
    // Replace content node with processed inline nodes
    guard let parent = node.parent as? MarkdownNodeBase else { 
      print("DEBUG: ContentNode has no valid parent!")
      return 
    }
    let index = parent.children.firstIndex { $0 === node } ?? 0
    node.remove()
    
    for (i, inlineNode) in inlineNodes.enumerated() {
      parent.insert(inlineNode, at: index + i)
    }
  }
}

// MARK: - Delimiter Stack Implementation

private enum DelimiterType: Hashable {
  case asterisk
  case underscore
  case openBracket
  case openImageBracket
}

private struct DelimiterRun {
  let type: DelimiterType
  let length: Int
  let canOpen: Bool
  let canClose: Bool
  let tokenIndex: Int
  let characterIndex: Int
  var isActive: Bool = true
  
  init(type: DelimiterType, length: Int, canOpen: Bool, canClose: Bool, tokenIndex: Int, characterIndex: Int) {
    self.type = type
    self.length = length
    self.canOpen = canOpen
    self.canClose = canClose
    self.tokenIndex = tokenIndex
    self.characterIndex = characterIndex
  }
}

private class DelimiterStackNode {
  var delimiterRun: DelimiterRun
  var textNode: TextNode?
  weak var previous: DelimiterStackNode?
  var next: DelimiterStackNode?
  
  init(delimiterRun: DelimiterRun, textNode: TextNode? = nil) {
    self.delimiterRun = delimiterRun
    self.textNode = textNode
  }
}

private class DelimiterStack {
  private var head: DelimiterStackNode?
  private var tail: DelimiterStackNode?
  
  func push(_ delimiterRun: DelimiterRun, textNode: TextNode? = nil) {
    let node = DelimiterStackNode(delimiterRun: delimiterRun, textNode: textNode)
    
    if let currentTail = tail {
      currentTail.next = node
      node.previous = currentTail
      tail = node
    } else {
      head = node
      tail = node
    }
  }
  
  func remove(_ node: DelimiterStackNode) {
    if node.previous != nil {
      node.previous?.next = node.next
    } else {
      head = node.next
    }
    
    if node.next != nil {
      node.next?.previous = node.previous
    } else {
      tail = node.previous
    }
  }
  
  func findLastOpener(for type: DelimiterType, before node: DelimiterStackNode?) -> DelimiterStackNode? {
    var current = node?.previous ?? tail
    while let currentNode = current {
      if currentNode.delimiterRun.type == type && 
         currentNode.delimiterRun.canOpen && 
         currentNode.delimiterRun.isActive {
        return currentNode
      }
      current = currentNode.previous
    }
    return nil
  }
  
  func removeAll(after stackBottom: DelimiterStackNode?) {
    var current = stackBottom?.next ?? head
    while let node = current {
      let next = node.next
      remove(node)
      current = next
    }
  }
  
  var isEmpty: Bool {
    return head == nil
  }
  
  func iterateForward(from start: DelimiterStackNode?) -> DelimiterStackIterator {
    return DelimiterStackIterator(current: start ?? head)
  }
}

private struct DelimiterStackIterator: IteratorProtocol {
  private var current: DelimiterStackNode?
  
  init(current: DelimiterStackNode?) {
    self.current = current
  }
  
  mutating func next() -> DelimiterStackNode? {
    let result = current
    current = current?.next
    return result
  }
}

// MARK: - Character Classification Utilities

private extension Character {
  var isWhitespace: Bool {
    return MarkdownCharacter.whitespaces.contains(self)
  }
  
  var isPunctuation: Bool {
    return MarkdownCharacter.punctuations.contains(self)
  }
  
  var isAlphanumeric: Bool {
    return self.isLetter || self.isNumber
  }
}

private struct CharacterClassifier {
  static func classifyDelimiterRun(
    character: Character,
    precedingChar: Character?,
    followingChar: Character?
  ) -> (canOpen: Bool, canClose: Bool) {
    let isLeftFlanking = !character.isWhitespace && 
                        (precedingChar == nil || precedingChar!.isWhitespace || precedingChar!.isPunctuation)
    let isRightFlanking = !character.isWhitespace && 
                         (followingChar == nil || followingChar!.isWhitespace || followingChar!.isPunctuation)
    
    switch character {
    case "*":
      return (canOpen: isLeftFlanking, canClose: isRightFlanking)
    case "_":
      let canOpen = isLeftFlanking && 
                   (precedingChar == nil || precedingChar!.isPunctuation || precedingChar!.isWhitespace)
      let canClose = isRightFlanking && 
                    (followingChar == nil || followingChar!.isPunctuation || followingChar!.isWhitespace)
      return (canOpen: canOpen, canClose: canClose)
    default:
      return (canOpen: false, canClose: false)
    }
  }
}

// MARK: - Inline Processor

private class InlineProcessor {
  private let tokens: [any CodeToken<MarkdownTokenElement>]
  private var delimiterStack = DelimiterStack()
  private var inlineNodes: [MarkdownNodeBase] = []
  private var currentTokenIndex = 0
  
  init(tokens: [any CodeToken<MarkdownTokenElement>]) {
    self.tokens = tokens
  }
  
  func process() -> [MarkdownNodeBase] {
    while currentTokenIndex < tokens.count {
      processToken()
    }
    
    // Process remaining emphasis delimiters
    processEmphasis(stackBottom: nil)
    
    return inlineNodes
  }
  
  private func processToken() {
    guard currentTokenIndex < tokens.count else { return }
    let token = tokens[currentTokenIndex]
    
    switch token.element {
    case .characters:
      processCharacters(token)
    case .punctuation:
      processPunctuation(token)
    case .newline:
      processNewline(token)
    case .whitespaces:
      processWhitespace(token)
    case .charef:
      processCharacterReference(token)
    case .hardbreak:
      processHardBreak(token)
    case .eof:
      break
    }
    
    currentTokenIndex += 1
  }
  
  private func processCharacters(_ token: any CodeToken<MarkdownTokenElement>) {
    addTextNode(with: token.text)
  }
  
  private func processPunctuation(_ token: any CodeToken<MarkdownTokenElement>) {
    let char = token.text.first!
    
    switch char {
    case "*", "_":
      processEmphasisDelimiter(char, token: token)
    case "[":
      processOpenBracket(token)
    case "]":
      processCloseBracket(token)
    default:
      addTextNode(with: token.text)
    }
  }
  
  private func processNewline(_ token: any CodeToken<MarkdownTokenElement>) {
    inlineNodes.append(LineBreakNode(variant: .soft))
  }
  
  private func processWhitespace(_ token: any CodeToken<MarkdownTokenElement>) {
    addTextNode(with: token.text)
  }
  
  private func processCharacterReference(_ token: any CodeToken<MarkdownTokenElement>) {
    addTextNode(with: token.text)
  }
  
  private func processHardBreak(_ token: any CodeToken<MarkdownTokenElement>) {
    inlineNodes.append(LineBreakNode(variant: .hard))
  }
  
  private func processEmphasisDelimiter(_ char: Character, token: any CodeToken<MarkdownTokenElement>) {
    // Count consecutive delimiter characters
    var length = 1
    var nextIndex = currentTokenIndex + 1
    
    while nextIndex < tokens.count && 
          tokens[nextIndex].element == .punctuation && 
          tokens[nextIndex].text.first == char {
      length += 1
      nextIndex += 1
    }
    
    // Get preceding and following characters for flanking detection
    let precedingChar = getPrecedingCharacter()
    let followingChar = getFollowingCharacter(at: nextIndex - 1)
    
    let classification = CharacterClassifier.classifyDelimiterRun(
      character: char,
      precedingChar: precedingChar,
      followingChar: followingChar
    )
    
    // Create text node with the delimiter run
    let delimiterText = String(repeating: char, count: length)
    let textNode = TextNode(content: delimiterText)
    addInlineNode(textNode)
    
    // Add to delimiter stack if it can open or close
    if classification.canOpen || classification.canClose {
      let delimiterType: DelimiterType = char == "*" ? .asterisk : .underscore
      let delimiterRun = DelimiterRun(
        type: delimiterType,
        length: length,
        canOpen: classification.canOpen,
        canClose: classification.canClose,
        tokenIndex: currentTokenIndex,
        characterIndex: 0
      )
      
      delimiterStack.push(delimiterRun, textNode: textNode)
    }
    
    // Skip the processed delimiter tokens
    currentTokenIndex = nextIndex - 1
  }
  
  private func processOpenBracket(_ token: any CodeToken<MarkdownTokenElement>) {
    // Check if this is an image bracket (preceded by !)
    let isImage = checkForImageBracket()
    
    let delimiterType: DelimiterType = isImage ? .openImageBracket : .openBracket
    let textNode = TextNode(content: isImage ? "![" : "[")
    addInlineNode(textNode)
    
    let delimiterRun = DelimiterRun(
      type: delimiterType,
      length: 1,
      canOpen: true,
      canClose: false,
      tokenIndex: currentTokenIndex,
      characterIndex: 0
    )
    
    delimiterStack.push(delimiterRun, textNode: textNode)
  }
  
  private func processCloseBracket(_ token: any CodeToken<MarkdownTokenElement>) {
    lookForLinkOrImage()
  }
  
  private func checkForImageBracket() -> Bool {
    // Check if there's a preceding exclamation mark
    guard currentTokenIndex > 0 else { return false }
    let prevToken = tokens[currentTokenIndex - 1]
    
    if prevToken.element == .punctuation && prevToken.text == "!" {
      // Remove the last text node if it's just the exclamation mark
      if let lastNode = inlineNodes.last as? TextNode, lastNode.content == "!" {
        lastNode.remove()
        inlineNodes.removeLast()
      }
      return true
    }
    
    return false
  }
  
  // Implementation of "look for link or image" procedure
  private func lookForLinkOrImage() {
    // Find the last [ or ![ opener
    guard let opener = delimiterStack.findLastOpener(for: .openBracket, before: nil) ?? 
                      delimiterStack.findLastOpener(for: .openImageBracket, before: nil) else {
      addTextNode(with: "]")
      return
    }
    
    if !opener.delimiterRun.isActive {
      delimiterStack.remove(opener)
      addTextNode(with: "]")
      return
    }
    
    // Try to parse link/image after ]
    if let linkInfo = parseLinkDestination() {
      // Create link or image node
      let isImage = opener.delimiterRun.type == .openImageBracket
      
      if isImage {
        let imageNode = ImageNode(url: linkInfo.url, alt: linkInfo.text, title: linkInfo.title)
        // Add text content as child
        collectInlinesBetween(opener: opener, into: imageNode)
        replaceWithNode(imageNode, from: opener)
      } else {
        let linkNode = LinkNode(url: linkInfo.url, title: linkInfo.title)
        collectInlinesBetween(opener: opener, into: linkNode)
        replaceWithNode(linkNode, from: opener)
        
        // Deactivate all [ delimiters before this opener
        deactivateBracketDelimiters(before: opener)
      }
      
      // Process emphasis within the link/image
      processEmphasis(stackBottom: opener)
      delimiterStack.remove(opener)
    } else {
      delimiterStack.remove(opener)
      addTextNode(with: "]")
    }
  }
  
  // Implementation of "process emphasis" procedure  
  private func processEmphasis(stackBottom: DelimiterStackNode?) {
    var openersBottom: [DelimiterType: [Int: DelimiterStackNode?]] = [:]
    
    // Initialize openers_bottom for each delimiter type and length modulo 3
    for delimiterType in [DelimiterType.asterisk, DelimiterType.underscore] {
      openersBottom[delimiterType] = [0: stackBottom, 1: stackBottom, 2: stackBottom]
    }
    
    var currentPosition = stackBottom?.next
    
    while let current = currentPosition {
      // Look for potential closer
      if (current.delimiterRun.type == .asterisk || current.delimiterRun.type == .underscore) && 
         current.delimiterRun.canClose {
        
        let delimiterType = current.delimiterRun.type
        let lengthMod3 = current.delimiterRun.length % 3
        
        // Look for matching opener
        var opener = current.previous
        let bottomNode = openersBottom[delimiterType]?[lengthMod3] ?? nil
        while let currentOpener = opener, currentOpener !== bottomNode {
          if currentOpener.delimiterRun.type == delimiterType && 
             currentOpener.delimiterRun.canOpen && 
             currentOpener.delimiterRun.isActive {
            
            // Found matching opener
            let isStrong = currentOpener.delimiterRun.length >= 2 && current.delimiterRun.length >= 2
            let consumeLength = isStrong ? 2 : 1
            
            // Create emphasis or strong node
            let emphasisNode = isStrong ? StrongNode(content: "") : EmphasisNode(content: "")
            
            // Collect inlines between opener and closer
            collectInlinesBetween(opener: currentOpener, closer: current, into: emphasisNode)
            
            // Remove delimiters from text nodes
            updateDelimiterTextNode(currentOpener, consumeFromStart: consumeLength)
            updateDelimiterTextNode(current, consumeFromEnd: consumeLength)
            
            // Update delimiter runs
            currentOpener.delimiterRun = DelimiterRun(
              type: currentOpener.delimiterRun.type,
              length: currentOpener.delimiterRun.length - consumeLength,
              canOpen: currentOpener.delimiterRun.canOpen,
              canClose: currentOpener.delimiterRun.canClose,
              tokenIndex: currentOpener.delimiterRun.tokenIndex,
              characterIndex: currentOpener.delimiterRun.characterIndex
            )
            
            current.delimiterRun = DelimiterRun(
              type: current.delimiterRun.type,
              length: current.delimiterRun.length - consumeLength,
              canOpen: current.delimiterRun.canOpen,
              canClose: current.delimiterRun.canClose,
              tokenIndex: current.delimiterRun.tokenIndex,
              characterIndex: current.delimiterRun.characterIndex
            )
            
            // Remove nodes with zero length
            if currentOpener.delimiterRun.length == 0 {
              currentOpener.textNode?.remove()
              delimiterStack.remove(currentOpener)
            }
            
            if current.delimiterRun.length == 0 {
              current.textNode?.remove()
              let next = current.next
              delimiterStack.remove(current)
              currentPosition = next
            } else {
              currentPosition = current.next
            }
            
            // Insert the emphasis node
            insertEmphasisNode(emphasisNode, after: currentOpener)
            
            break
          }
          opener = currentOpener.previous
        }
        
        if opener === bottomNode {
          // No matching opener found
          openersBottom[delimiterType]?[lengthMod3] = current.previous
          
          if !current.delimiterRun.canOpen {
            delimiterStack.remove(current)
          }
          
          currentPosition = current.next
        }
      } else {
        currentPosition = current.next
      }
    }
    
    // Remove all delimiters above stack_bottom
    delimiterStack.removeAll(after: stackBottom)
  }
  
  // Helper methods
  
  private func addTextNode(with text: String) {
    if let lastNode = inlineNodes.last as? TextNode {
      lastNode.content += text
    } else {
      addInlineNode(TextNode(content: text))
    }
  }
  
  private func addInlineNode(_ node: MarkdownNodeBase) {
    inlineNodes.append(node)
  }
  
  private func getPrecedingCharacter() -> Character? {
    guard currentTokenIndex > 0 else { return nil }
    let prevToken = tokens[currentTokenIndex - 1]
    return prevToken.text.last
  }
  
  private func getFollowingCharacter(at index: Int) -> Character? {
    guard index + 1 < tokens.count else { return nil }
    let nextToken = tokens[index + 1]
    return nextToken.text.first
  }
  
  private struct LinkInfo {
    let url: String
    let title: String
    let text: String
  }
  
  private func parseLinkDestination() -> LinkInfo? {
    // Simplified link parsing - look for (url) or (url "title")
    guard currentTokenIndex + 1 < tokens.count else { return nil }
    
    let nextToken = tokens[currentTokenIndex + 1]
    if nextToken.element == .punctuation && nextToken.text == "(" {
      // Parse inline link
      return parseInlineLink()
    }
    
    // Could implement reference link parsing here
    return nil
  }
  
  private func parseInlineLink() -> LinkInfo? {
    var index = currentTokenIndex + 2 // Skip ] and (
    var url = ""
    var title = ""
    
    // Parse URL
    while index < tokens.count {
      let token = tokens[index]
      if token.element == .punctuation && token.text == ")" {
        currentTokenIndex = index
        return LinkInfo(url: url.trimmingCharacters(in: .whitespacesAndNewlines), title: title, text: "")
      } else if token.element == .punctuation && token.text == "\"" {
        // Start of title
        index += 1
        while index < tokens.count {
          let titleToken = tokens[index]
          if titleToken.element == .punctuation && titleToken.text == "\"" {
            break
          }
          title += titleToken.text
          index += 1
        }
      } else {
        url += token.text
      }
      index += 1
    }
    
    return nil
  }
  
  private func collectInlinesBetween(opener: DelimiterStackNode, into node: MarkdownNodeBase) {
    // Find the position of the opener in inlineNodes and collect everything after it
    guard let openerTextNode = opener.textNode,
          let openerIndex = inlineNodes.firstIndex(where: { $0 === openerTextNode }) else { return }
    
    let startIndex = openerIndex + 1
    let nodesToMove = Array(inlineNodes[startIndex...])
    
    for childNode in nodesToMove {
      childNode.remove()
      node.append(childNode)
    }
    
    inlineNodes.removeSubrange(startIndex...)
  }
  
  private func collectInlinesBetween(opener: DelimiterStackNode, closer: DelimiterStackNode, into node: MarkdownNodeBase) {
    guard let openerTextNode = opener.textNode,
          let closerTextNode = closer.textNode,
          let openerIndex = inlineNodes.firstIndex(where: { $0 === openerTextNode }),
          let closerIndex = inlineNodes.firstIndex(where: { $0 === closerTextNode }) else { return }
    
    let startIndex = openerIndex + 1
    let endIndex = closerIndex
    
    guard startIndex < endIndex else { return }
    
    let nodesToMove = Array(inlineNodes[startIndex..<endIndex])
    
    for childNode in nodesToMove {
      childNode.remove()
      node.append(childNode)
    }
    
    inlineNodes.removeSubrange(startIndex..<endIndex)
  }
  
  private func replaceWithNode(_ newNode: MarkdownNodeBase, from opener: DelimiterStackNode) {
    guard let openerTextNode = opener.textNode,
          let openerIndex = inlineNodes.firstIndex(where: { $0 === openerTextNode }) else { return }
    
    openerTextNode.remove()
    inlineNodes[openerIndex] = newNode
  }
  
  private func deactivateBracketDelimiters(before opener: DelimiterStackNode) {
    var current = opener.previous
    while let node = current {
      if node.delimiterRun.type == .openBracket {
        node.delimiterRun.isActive = false
      }
      current = node.previous
    }
  }
  
  private func updateDelimiterTextNode(_ delimiter: DelimiterStackNode, consumeFromStart count: Int) {
    guard let textNode = delimiter.textNode else { return }
    let content = textNode.content
    textNode.content = String(content.dropFirst(count))
  }
  
  private func updateDelimiterTextNode(_ delimiter: DelimiterStackNode, consumeFromEnd count: Int) {
    guard let textNode = delimiter.textNode else { return }
    let content = textNode.content
    textNode.content = String(content.dropLast(count))
  }
  
  private func insertEmphasisNode(_ node: MarkdownNodeBase, after delimiter: DelimiterStackNode) {
    guard let delimiterTextNode = delimiter.textNode,
          let index = inlineNodes.firstIndex(where: { $0 === delimiterTextNode }) else { return }
    
    inlineNodes.insert(node, at: index + 1)
  }
}
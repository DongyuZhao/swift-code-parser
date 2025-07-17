import Foundation

/// Consumer for handling code blocks
public class MarkdownCodeBlockConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if this is the start of a code fence (three or more backticks)
        if mdToken.kind == .backtick && mdToken.text.count >= 3 {
            context.tokens.removeFirst()
            
            // Read language identifier (optional)
            var languageIdentifier = ""
            while let token = context.tokens.first as? MarkdownToken,
                  token.kind != .newline && token.kind != .eof {
                languageIdentifier += token.text
                context.tokens.removeFirst()
            }
            
            // Skip newline
            if let token = context.tokens.first as? MarkdownToken,
               token.kind == .newline {
                context.tokens.removeFirst()
            }
            
            // Collect code block content
            var codeContent = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .backtick && token.text.count >= 3 {
                    // End of code block
                    context.tokens.removeFirst()
                    break
                } else {
                    codeContent += token.text
                    context.tokens.removeFirst()
                }
            }
            
            let codeBlockNode = CodeNode(type: MarkdownElement.fencedCodeBlock, value: codeContent.trimmingCharacters(in: .newlines), range: mdToken.range)
            
            // If there's a language identifier, add it as a child node
            if !languageIdentifier.trimmingCharacters(in: .whitespaces).isEmpty {
                let langNode = CodeNode(type: MarkdownElement.text, value: languageIdentifier.trimmingCharacters(in: .whitespaces), range: nil)
                codeBlockNode.addChild(langNode)
            }
            
            context.currentNode.addChild(codeBlockNode)
            return true
        }
        
        return false
    }
}

/// Consumer for handling blockquotes
public class MarkdownBlockquoteConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .greaterThan && mdToken.isAtLineStart {
            // Get or create blockquote container
            let blockquoteNode = self.getOrCreateBlockquoteContainer(context: &context)
            
            context.tokens.removeFirst()
            
            // Skip optional space
            while let spaceToken = context.tokens.first as? MarkdownToken,
                  spaceToken.kind == .whitespace {
                context.tokens.removeFirst()
            }
            
            // Collect blockquote content
            var content = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .newline || token.kind == .eof {
                    break
                }
                content += token.text
                context.tokens.removeFirst()
            }
            
            // Add content to blockquote
            if !content.isEmpty {
                if !blockquoteNode.value.isEmpty {
                    blockquoteNode.value += "\n"
                }
                blockquoteNode.value += content.trimmingCharacters(in: .whitespaces)
            }
            
            return true
        }
        
        return false
    }
    
    private func getOrCreateBlockquoteContainer(context: inout CodeContext) -> CodeNode {
        // Check if current node is already a blockquote
        if let element = context.currentNode.type as? MarkdownElement,
           element == .blockquote {
            return context.currentNode
        }
        
        // Check if the last child of parent node is a blockquote
        if let lastChild = context.currentNode.children.last,
           let element = lastChild.type as? MarkdownElement,
           element == .blockquote {
            return lastChild
        }
        
        // Create new blockquote container
        let blockquoteNode = CodeNode(type: MarkdownElement.blockquote, value: "", range: nil)
        context.currentNode.addChild(blockquoteNode)
        return blockquoteNode
    }
}

/// Consumer for handling lists
public class MarkdownListConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Detect unordered lists
        if (mdToken.kind == .asterisk || mdToken.kind == .dash || mdToken.kind == .plus) && mdToken.isAtLineStart {
            // Check if it matches list format: marker should be followed by space or directly to line end
            if let nextToken = context.tokens.dropFirst().first as? MarkdownToken {
                if nextToken.kind == .whitespace || nextToken.kind == .newline || nextToken.kind == .eof {
                    return self.processUnorderedList(context: &context, marker: mdToken)
                }
            } else {
                // If there's no next token, it's also a valid list marker
                return self.processUnorderedList(context: &context, marker: mdToken)
            }
        }
        
        // Detect ordered lists (starting with digits)
        if mdToken.kind == .digit && mdToken.isAtLineStart {
            return self.processOrderedList(context: &context, firstDigit: mdToken)
        }
        
        return false
    }
    
    func processUnorderedList(context: inout CodeContext, marker: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove marker
        
        // Skip spaces
        while let token = context.tokens.first as? MarkdownToken,
              token.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // Check if this is a task list
        if let isChecked = self.checkForTaskList(context: &context) {
            return self.processTaskList(context: &context, marker: marker, isChecked: isChecked)
        }
        
        // Get or create unordered list container
        let listNode = self.getOrCreateUnorderedListContainer(context: &context)
        
        // Create list item
        let itemNode = CodeNode(type: MarkdownElement.listItem, value: "", range: marker.range)
        listNode.addChild(itemNode)
        
        // Collect list item content
        let oldCurrentNode = context.currentNode
        context.currentNode = itemNode
        
        var content = ""
        while let token = context.tokens.first as? MarkdownToken {
            if token.kind == .newline || token.kind == .eof {
                break
            }
            content += token.text
            context.tokens.removeFirst()
        }
        
        if !content.isEmpty {
            let textNode = CodeNode(type: MarkdownElement.text, value: content.trimmingCharacters(in: .whitespaces), range: marker.range)
            itemNode.addChild(textNode)
        }
        
        context.currentNode = oldCurrentNode
        return true
    }
    
    func checkForTaskList(context: inout CodeContext) -> Bool? {
        // Check pattern: [x] or [ ]
        guard context.tokens.count >= 3,
              let leftBracket = context.tokens[0] as? MarkdownToken,
              leftBracket.kind == .leftBracket,
              let content = context.tokens[1] as? MarkdownToken,
              let rightBracket = context.tokens[2] as? MarkdownToken,
              rightBracket.kind == .rightBracket else {
            return nil
        }
        
        let isChecked: Bool
        if content.text.trimmingCharacters(in: .whitespaces).isEmpty {
            isChecked = false
        } else if content.text.lowercased().contains("x") {
            isChecked = true
        } else {
            return nil
        }
        
        return isChecked
    }
    
    func processTaskList(context: inout CodeContext, marker: MarkdownToken, isChecked: Bool) -> Bool {
        // Remove [x] or [ ] tokens
        context.tokens.removeFirst() // [
        context.tokens.removeFirst() // x or space
        context.tokens.removeFirst() // ]
        
        // Skip subsequent spaces
        while let token = context.tokens.first as? MarkdownToken,
              token.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // Get or create task list container
        let taskListNode = self.getOrCreateTaskListContainer(context: &context)
        
        // Create task list item
        let itemNode = CodeNode(type: MarkdownElement.taskListItem, value: isChecked ? "[x]" : "[ ]", range: marker.range)
        
        taskListNode.addChild(itemNode)
        
        // Collect list item content
        let oldCurrentNode = context.currentNode
        context.currentNode = itemNode
        
        var content = ""
        while let token = context.tokens.first as? MarkdownToken {
            if token.kind == .newline || token.kind == .eof {
                break
            }
            content += token.text
            context.tokens.removeFirst()
        }
        
        if !content.isEmpty {
            let textNode = CodeNode(type: MarkdownElement.text, value: content.trimmingCharacters(in: .whitespaces), range: marker.range)
            itemNode.addChild(textNode)
        }
        
        context.currentNode = oldCurrentNode
        return true
    }
    
    func processOrderedList(context: inout CodeContext, firstDigit: MarkdownToken) -> Bool {
        var tokenIndex = 0
        
        // Collect all consecutive digits
        while tokenIndex < context.tokens.count,
              let token = context.tokens[tokenIndex] as? MarkdownToken,
              token.kind == .digit {
            tokenIndex += 1
        }
        
        // Check if followed by a dot
        guard tokenIndex < context.tokens.count,
              let dotToken = context.tokens[tokenIndex] as? MarkdownToken,
              dotToken.kind == .dot else {
            return false
        }
        
        // Check if there's a space after the dot
        guard tokenIndex + 1 < context.tokens.count,
              let spaceToken = context.tokens[tokenIndex + 1] as? MarkdownToken,
              spaceToken.kind == .whitespace else {
            return false
        }
        
        // Remove digits, dot, and space
        for _ in 0...(tokenIndex + 1) {
            context.tokens.removeFirst()
        }
        
        // Get or create ordered list container
        let listNode = self.getOrCreateOrderedListContainer(context: &context)
        
        // Create list item with automatic numbering
        let itemNumber = listNode.children.count + 1
        let itemNode = CodeNode(type: MarkdownElement.listItem, value: "\(itemNumber).", range: firstDigit.range)
        
        listNode.addChild(itemNode)
        
        // Collect list item content
        let oldCurrentNode = context.currentNode
        context.currentNode = itemNode
        
        var content = ""
        while let token = context.tokens.first as? MarkdownToken {
            if token.kind == .newline || token.kind == .eof {
                break
            }
            content += token.text
            context.tokens.removeFirst()
        }
        
        if !content.isEmpty {
            let textNode = CodeNode(type: MarkdownElement.text, value: content.trimmingCharacters(in: .whitespaces), range: firstDigit.range)
            itemNode.addChild(textNode)
        }
        
        context.currentNode = oldCurrentNode
        return true
    }
    
    func getOrCreateOrderedListContainer(context: inout CodeContext) -> CodeNode {
        // Check if current node is already an ordered list
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .orderedList {
            return context.currentNode
        }
        
        // Check if parent node is an ordered list
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .orderedList {
            context.currentNode = parent
            return parent
        }
        
        // Create new ordered list container
        let listNode = CodeNode(type: MarkdownElement.orderedList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
    
    func getOrCreateUnorderedListContainer(context: inout CodeContext) -> CodeNode {
        // Check if current node is already an unordered list
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .unorderedList {
            return context.currentNode
        }
        
        // Check if parent node is an unordered list
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .unorderedList {
            context.currentNode = parent
            return parent
        }
        
        // Create new unordered list container
        let listNode = CodeNode(type: MarkdownElement.unorderedList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
    
    func getOrCreateTaskListContainer(context: inout CodeContext) -> CodeNode {
        // Check if current node is already a task list
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .taskList {
            return context.currentNode
        }
        
        // Check if parent node is a task list
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .taskList {
            context.currentNode = parent
            return parent
        }
        
        // Create new task list container
        let listNode = CodeNode(type: MarkdownElement.taskList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
}

/// Consumer for handling horizontal rules
public class MarkdownHorizontalRuleConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .horizontalRule && mdToken.isAtLineStart {
            context.tokens.removeFirst()
            
            // Skip remaining content on the line
            while let currentToken = context.tokens.first as? MarkdownToken,
                  currentToken.kind != .newline && currentToken.kind != .eof {
                context.tokens.removeFirst()
            }
            
            let hrNode = CodeNode(type: MarkdownElement.horizontalRule, value: "---", range: mdToken.range)
            context.currentNode.addChild(hrNode)
            
            return true
        }
        
        return false
    }
}

/// Consumer for handling footnote definitions
public class MarkdownFootnoteDefinitionConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if this is the start of a footnote definition: [^identifier]:
        if mdToken.kind == .leftBracket && mdToken.isAtLineStart {
            // Check if the next token is ^
            guard context.tokens.count >= 2,
                  let caretToken = context.tokens[1] as? MarkdownToken,
                  caretToken.kind == .caret else {
                return false
            }
            
            // Collect footnote identifier
            var tokenIndex = 2
            var identifier = ""
            while tokenIndex < context.tokens.count {
                guard let token = context.tokens[tokenIndex] as? MarkdownToken else { break }
                if token.kind == .rightBracket {
                    tokenIndex += 1
                    break
                }
                identifier += token.text
                tokenIndex += 1
            }
            
            // Check if followed by colon
            guard tokenIndex < context.tokens.count,
                  let colonToken = context.tokens[tokenIndex] as? MarkdownToken,
                  colonToken.kind == .colon else {
                return false
            }
            
            // Remove processed tokens
            for _ in 0...tokenIndex {
                context.tokens.removeFirst()
            }
            
            // Skip spaces
            while let token = context.tokens.first as? MarkdownToken,
                  token.kind == .whitespace {
                context.tokens.removeFirst()
            }
            
            // Collect footnote content
            var content = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .newline || token.kind == .eof {
                    break
                }
                content += token.text
                context.tokens.removeFirst()
            }
            
            let footnoteNode = CodeNode(type: MarkdownElement.footnoteDefinition, value: identifier, range: mdToken.range)
            
            // Add content as child node
            if !content.isEmpty {
                let contentNode = CodeNode(type: MarkdownElement.text, value: content.trimmingCharacters(in: .whitespaces), range: mdToken.range)
                footnoteNode.addChild(contentNode)
            }
            
            context.currentNode.addChild(footnoteNode)
            return true
        }
        
        return false
    }
}

/// Consumer for handling citation definitions
public class MarkdownCitationDefinitionConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if this is the start of a citation definition: [@identifier]:
        if mdToken.kind == .leftBracket && mdToken.isAtLineStart {
            // Check if the next token is @
            guard context.tokens.count >= 2,
                  let atToken = context.tokens[1] as? MarkdownToken,
                  atToken.kind == .atSign else {
                return false
            }
            
            // Collect citation identifier
            var tokenIndex = 2
            var identifier = ""
            while tokenIndex < context.tokens.count {
                guard let token = context.tokens[tokenIndex] as? MarkdownToken else { break }
                if token.kind == .rightBracket {
                    tokenIndex += 1
                    break
                }
                identifier += token.text
                tokenIndex += 1
            }
            
            // Check if followed by colon
            guard tokenIndex < context.tokens.count,
                  let colonToken = context.tokens[tokenIndex] as? MarkdownToken,
                  colonToken.kind == .colon else {
                return false
            }
            
            // Remove processed tokens
            for _ in 0...tokenIndex {
                context.tokens.removeFirst()
            }
            
            // Skip spaces
            while let token = context.tokens.first as? MarkdownToken,
                  token.kind == .whitespace {
                context.tokens.removeFirst()
            }
            
            // Collect citation content
            var content = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .newline || token.kind == .eof {
                    break
                }
                content += token.text
                context.tokens.removeFirst()
            }
            
            let citationNode = CodeNode(type: MarkdownElement.citation, value: identifier, range: mdToken.range)
            
            // Add content as child node
            if !content.isEmpty {
                let contentNode = CodeNode(type: MarkdownElement.text, value: content.trimmingCharacters(in: .whitespaces), range: mdToken.range)
                citationNode.addChild(contentNode)
            }
            
            context.currentNode.addChild(citationNode)
            return true
        }
        
        return false
    }
}

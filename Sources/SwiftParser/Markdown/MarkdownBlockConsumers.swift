import Foundation

/// 处理代码块的Consumer
public class MarkdownCodeBlockConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检查是否是代码栅栏开始（三个或更多反引号）
        if mdToken.kind == .backtick && mdToken.text.count >= 3 {
            context.tokens.removeFirst()
            
            // 读取语言标识符（可选）
            var languageIdentifier = ""
            while let token = context.tokens.first as? MarkdownToken,
                  token.kind != .newline && token.kind != .eof {
                languageIdentifier += token.text
                context.tokens.removeFirst()
            }
            
            // 跳过换行
            if let token = context.tokens.first as? MarkdownToken,
               token.kind == .newline {
                context.tokens.removeFirst()
            }
            
            // 收集代码块内容
            var codeContent = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .backtick && token.text.count >= 3 {
                    // 代码块结束
                    context.tokens.removeFirst()
                    break
                } else {
                    codeContent += token.text
                    context.tokens.removeFirst()
                }
            }
            
            let codeBlockNode = CodeNode(type: MarkdownElement.fencedCodeBlock, value: codeContent.trimmingCharacters(in: .newlines), range: mdToken.range)
            
            // 如果有语言标识符，添加为子节点
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

/// 处理引用的Consumer
public class MarkdownBlockquoteConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .greaterThan && mdToken.isAtLineStart {
            // 获取或创建引用块容器
            let blockquoteNode = self.getOrCreateBlockquoteContainer(context: &context)
            
            context.tokens.removeFirst()
            
            // 跳过可选的空格
            while let spaceToken = context.tokens.first as? MarkdownToken,
                  spaceToken.kind == .whitespace {
                context.tokens.removeFirst()
            }
            
            // 收集引用内容
            var content = ""
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .newline || token.kind == .eof {
                    break
                }
                content += token.text
                context.tokens.removeFirst()
            }
            
            // 添加内容到引用块
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
        // 检查当前节点是否已经是引用块
        if let element = context.currentNode.type as? MarkdownElement,
           element == .blockquote {
            return context.currentNode
        }
        
        // 检查父节点的最后一个子节点是否是引用块
        if let lastChild = context.currentNode.children.last,
           let element = lastChild.type as? MarkdownElement,
           element == .blockquote {
            return lastChild
        }
        
        // 创建新的引用块容器
        let blockquoteNode = CodeNode(type: MarkdownElement.blockquote, value: "", range: nil)
        context.currentNode.addChild(blockquoteNode)
        return blockquoteNode
    }
}

/// 处理列表的Consumer
public class MarkdownListConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检测无序列表
        if (mdToken.kind == .asterisk || mdToken.kind == .dash || mdToken.kind == .plus) && mdToken.isAtLineStart {
            // 检查是否符合列表格式：标记后面应该跟空格或直接到行末
            if let nextToken = context.tokens.dropFirst().first as? MarkdownToken {
                if nextToken.kind == .whitespace || nextToken.kind == .newline || nextToken.kind == .eof {
                    return self.processUnorderedList(context: &context, marker: mdToken)
                }
            } else {
                // 如果没有下一个token，也是有效的列表标记
                return self.processUnorderedList(context: &context, marker: mdToken)
            }
        }
        
        // 检测有序列表（数字开头）
        if mdToken.kind == .digit && mdToken.isAtLineStart {
            return self.processOrderedList(context: &context, firstDigit: mdToken)
        }
        
        return false
    }
    
    func processUnorderedList(context: inout CodeContext, marker: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // 移除标记
        
        // 跳过空格
        while let token = context.tokens.first as? MarkdownToken,
              token.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // 检查是否是任务列表
        if let isChecked = self.checkForTaskList(context: &context) {
            return self.processTaskList(context: &context, marker: marker, isChecked: isChecked)
        }
        
        // 获取或创建无序列表容器
        let listNode = self.getOrCreateUnorderedListContainer(context: &context)
        
        // 创建列表项
        let itemNode = CodeNode(type: MarkdownElement.listItem, value: "", range: marker.range)
        listNode.addChild(itemNode)
        
        // 收集列表项内容
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
        // 检查模式: [x] 或 [ ]
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
        // 移除 [x] 或 [ ] tokens
        context.tokens.removeFirst() // [
        context.tokens.removeFirst() // x 或 空格
        context.tokens.removeFirst() // ]
        
        // 跳过后续空格
        while let token = context.tokens.first as? MarkdownToken,
              token.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // 获取或创建任务列表容器
        let taskListNode = self.getOrCreateTaskListContainer(context: &context)
        
        // 创建任务列表项
        let itemNode = CodeNode(type: MarkdownElement.taskListItem, value: isChecked ? "[x]" : "[ ]", range: marker.range)
        
        taskListNode.addChild(itemNode)
        
        // 收集列表项内容
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
        
        // 收集所有连续的数字
        while tokenIndex < context.tokens.count,
              let token = context.tokens[tokenIndex] as? MarkdownToken,
              token.kind == .digit {
            tokenIndex += 1
        }
        
        // 检查是否跟着点号
        guard tokenIndex < context.tokens.count,
              let dotToken = context.tokens[tokenIndex] as? MarkdownToken,
              dotToken.kind == .dot else {
            return false
        }
        
        // 检查点号后是否有空格
        guard tokenIndex + 1 < context.tokens.count,
              let spaceToken = context.tokens[tokenIndex + 1] as? MarkdownToken,
              spaceToken.kind == .whitespace else {
            return false
        }
        
        // 移除数字、点号和空格
        for _ in 0...(tokenIndex + 1) {
            context.tokens.removeFirst()
        }
        
        // 获取或创建有序列表容器
        let listNode = self.getOrCreateOrderedListContainer(context: &context)
        
        // 创建列表项，使用自动编号
        let itemNumber = listNode.children.count + 1
        let itemNode = CodeNode(type: MarkdownElement.listItem, value: "\(itemNumber).", range: firstDigit.range)
        
        listNode.addChild(itemNode)
        
        // 收集列表项内容
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
        // 检查当前节点是否已经是有序列表
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .orderedList {
            return context.currentNode
        }
        
        // 检查父节点是否是有序列表
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .orderedList {
            context.currentNode = parent
            return parent
        }
        
        // 创建新的有序列表容器
        let listNode = CodeNode(type: MarkdownElement.orderedList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
    
    func getOrCreateUnorderedListContainer(context: inout CodeContext) -> CodeNode {
        // 检查当前节点是否已经是无序列表
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .unorderedList {
            return context.currentNode
        }
        
        // 检查父节点是否是无序列表
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .unorderedList {
            context.currentNode = parent
            return parent
        }
        
        // 创建新的无序列表容器
        let listNode = CodeNode(type: MarkdownElement.unorderedList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
    
    func getOrCreateTaskListContainer(context: inout CodeContext) -> CodeNode {
        // 检查当前节点是否已经是任务列表
        if let currentElement = context.currentNode.type as? MarkdownElement,
           currentElement == .taskList {
            return context.currentNode
        }
        
        // 检查父节点是否是任务列表
        if let parent = context.currentNode.parent,
           let parentElement = parent.type as? MarkdownElement,
           parentElement == .taskList {
            context.currentNode = parent
            return parent
        }
        
        // 创建新的任务列表容器
        let listNode = CodeNode(type: MarkdownElement.taskList, value: "", range: nil)
        context.currentNode.addChild(listNode)
        context.currentNode = listNode
        return listNode
    }
}

/// 处理水平线的Consumer
public class MarkdownHorizontalRuleConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .horizontalRule && mdToken.isAtLineStart {
            context.tokens.removeFirst()
            
            // 跳过行末的其他内容
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

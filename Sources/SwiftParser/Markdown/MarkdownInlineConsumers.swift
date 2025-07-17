import Foundation

/// 处理标题的Consumer，支持ATX标题（# 标题）
public class MarkdownHeaderConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检查是否是行首的#字符
        if mdToken.kind == .hash && mdToken.isAtLineStart {
            return consumeAtxHeader(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeAtxHeader(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // 移除当前#号token
        context.tokens.removeFirst()
        
        // 计算标题级别
        var level = 1
        var headerText = ""
        
        // 消费连续的#号
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind == .hash {
            level += 1
            context.tokens.removeFirst()
            
            // 最大支持6级标题
            if level > 6 {
                level = 6
                break
            }
        }
        
        // 跳过空白
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // 收集标题文本直到行末
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind != .newline && nextToken.kind != .eof {
            headerText += nextToken.text
            context.tokens.removeFirst()
        }
        
        // 移除尾部的#号和空白
        headerText = headerText.trimmingCharacters(in: .whitespaces)
        if headerText.hasSuffix("#") {
            headerText = String(headerText.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        // 创建对应级别的标题节点
        let headerElement: MarkdownElement
        switch level {
        case 1: headerElement = .header1
        case 2: headerElement = .header2
        case 3: headerElement = .header3
        case 4: headerElement = .header4
        case 5: headerElement = .header5
        default: headerElement = .header6
        }
        
        let headerNode = CodeNode(type: headerElement, value: headerText, range: token.range)
        context.currentNode.addChild(headerNode)
        
        return true
    }
}

/// 处理段落的Consumer
public class MarkdownParagraphConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 如果是文本token，开始段落
        if mdToken.kind == .text && mdToken.isAtLineStart {
            return consumeParagraph(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeParagraph(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // 创建段落节点
        let paragraphNode = CodeNode(type: MarkdownElement.paragraph, value: "", range: token.range)
        context.currentNode.addChild(paragraphNode)
        
        // 进入段落上下文
        let previousNode = context.currentNode
        context.currentNode = paragraphNode
        
        var paragraphText = ""
        
        // 收集段落内容直到遇到空行或块级元素
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof {
                break
            }
            
            if currentToken.kind == .newline {
                context.tokens.removeFirst()
                
                // 检查下一行是否为空行或块级元素开始
                if let nextToken = context.tokens.first as? MarkdownToken {
                    if nextToken.kind == .newline || isBlockElementStart(nextToken) {
                        break
                    }
                    // 如果不是空行，添加空格
                    paragraphText += " "
                }
                continue
            }
            
            // 尝试让内联consumers处理这个token
            var consumed = false
            for inlineConsumer in getInlineConsumers() {
                if inlineConsumer.consume(context: &context, token: currentToken) {
                    consumed = true
                    break
                }
            }
            
            // 如果没有内联consumer处理，添加到段落文本
            if !consumed {
                paragraphText += currentToken.text
                context.tokens.removeFirst()
            }
        }
        
        // 如果有剩余的文本，创建文本节点
        if !paragraphText.isEmpty {
            let textNode = CodeNode(type: MarkdownElement.text, value: paragraphText.trimmingCharacters(in: .whitespaces), range: token.range)
            paragraphNode.addChild(textNode)
        }
        
        // 恢复上下文
        context.currentNode = previousNode
        
        // 设置段落的值为所有子节点的文本内容
        paragraphNode.value = paragraphNode.children.map { $0.value }.joined()
        
        return true
    }
    
    private func getInlineConsumers() -> [CodeTokenConsumer] {
        return [
            MarkdownInlineCodeConsumer(),
            MarkdownLinkConsumer(),
            MarkdownImageConsumer(),
            MarkdownAutolinkConsumer(),
            MarkdownEmphasisConsumer(),
            MarkdownStrikethroughConsumer(),
            MarkdownHTMLInlineConsumer()
        ]
    }
    
    private func isBlockElementStart(_ token: MarkdownToken) -> Bool {
        return token.kind == .hash && token.isAtLineStart ||
               token.kind == .greaterThan && token.isAtLineStart ||
               token.kind == .backtick && token.isAtLineStart ||
               (token.kind == .asterisk || token.kind == .dash || token.kind == .plus) && token.isAtLineStart
    }
}

/// Token类型
enum FlatTokenType {
    case partial
    case text
    case other
}

/// 展平的token表示
struct FlatToken {
    let type: FlatTokenType
    let content: String
    let node: CodeNode?
    
    init(type: FlatTokenType, content: String, node: CodeNode? = nil) {
        self.type = type
        self.content = content
        self.node = node
    }
}

/// Emphasis匹配结果
struct EmphasisMatch {
    let endIndex: Int
    let count: Int
}

/// 节点组类型
enum NodeGroupType {
    case partial
    case content
}

/// 节点组
struct NodeGroup {
    let type: NodeGroupType
    var startIndex: Int
    var endIndex: Int
    var nodes: [CodeNode]
    var markerCount: Int
}

/// Emphasis重组方案
struct EmphasisReorganization {
    let startGroup: (index: Int, group: NodeGroup)
    let endGroup: (index: Int, group: NodeGroup)
    let contentGroups: [NodeGroup]
    let matchCount: Int
    let marker: String
}

/// 处理强调的Consumer（* 和 _），使用回溯重组策略
public class MarkdownEmphasisConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .asterisk || mdToken.kind == .underscore {
            return handleEmphasisToken(context: &context, token: mdToken)
        }
        
        return false
    }
    
    /// 处理emphasis token - 使用回溯重组策略
    private func handleEmphasisToken(context: inout CodeContext, token: MarkdownToken) -> Bool {
        let marker = token.text
        
        // 首先移除当前token并计算连续marker数量
        context.tokens.removeFirst()
        var markerCount = 1
        
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.text == marker,
              ((marker == "*" && nextToken.kind == .asterisk) || (marker == "_" && nextToken.kind == .underscore)) {
            markerCount += 1
            context.tokens.removeFirst()
        }
        
        print("handleEmphasisToken: marker='\(marker)', count=\(markerCount)")
        
        // 先添加新的partial nodes
        var newPartials: [CodeNode] = []
        for _ in 0..<markerCount {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: token.range
            )
            newPartials.append(partialNode)
            context.currentNode.addChild(partialNode)
        }
        
        // 然后回溯重组整个AST以寻找最佳emphasis结构
        backtrackAndReorganizeEmphasis(context: &context, marker: marker)
        
        return true
    }
    /// 回溯并重组emphasis结构 - 支持重新评估已有结构
    private func backtrackAndReorganizeEmphasis(context: inout CodeContext, marker: String) {
        let parentNode = context.currentNode
        
        print("开始回溯重组，当前子节点数量: \(parentNode.children.count)")
        
        // 如果是新添加的partial markers，先尝试全局重组
        if shouldPerformGlobalReorganization(parentNode, marker: marker) {
            print("检测到需要全局重组")
            performGlobalReorganization(parentNode, marker: marker)
            return
        }
        
        // 否则进行常规的多轮重组
        performLocalReorganization(parentNode, marker: marker)
    }
    
    /// 检查是否需要进行全局重组
    private func shouldPerformGlobalReorganization(_ parentNode: CodeNode, marker: String) -> Bool {
        // 统计partial markers和emphasis节点
        var partialCount = 0
        var emphasisCount = 0
        
        for child in parentNode.children {
            if let element = child.type as? MarkdownElement {
                if element == .partialEmphasis && child.value == marker {
                    partialCount += 1
                } else if element == .emphasis || element == .strongEmphasis {
                    emphasisCount += 1
                }
            }
        }
        
        // 如果有多个partial markers和emphasis节点，可能需要全局重组
        return partialCount >= 2 && emphasisCount > 0
    }
    
    /// 执行全局重组：将所有内容展平后重新匹配
    private func performGlobalReorganization(_ parentNode: CodeNode, marker: String) {
        print("开始全局重组")
        
        // 收集所有的原始tokens和内容
        var flatTokens: [FlatToken] = []
        
        for child in parentNode.children {
            flattenNode(child, into: &flatTokens, marker: marker)
        }
        
        print("展平后的tokens: \(flatTokens.count)个")
        for (i, token) in flatTokens.enumerated() {
            print("  [\(i)]: \(token.type) = '\(token.content)'")
        }
        
        // 清空现有的children
        parentNode.children.removeAll()
        
        // 重新构建emphasis结构
        rebuildEmphasisStructure(parentNode, flatTokens: flatTokens, marker: marker)
    }
    
    /// 展平节点为tokens
    private func flattenNode(_ node: CodeNode, into tokens: inout [FlatToken], marker: String) {
        if let element = node.type as? MarkdownElement {
            switch element {
            case .partialEmphasis:
                if node.value == marker {
                    tokens.append(FlatToken(type: .partial, content: marker))
                }
            case .emphasis, .strongEmphasis:
                // 提取emphasis的markers和内容
                let markerCount = element == .strongEmphasis ? 2 : 1
                for _ in 0..<markerCount {
                    tokens.append(FlatToken(type: .partial, content: marker))
                }
                for child in node.children {
                    flattenNode(child, into: &tokens, marker: marker)
                }
                for _ in 0..<markerCount {
                    tokens.append(FlatToken(type: .partial, content: marker))
                }
            case .text:
                tokens.append(FlatToken(type: .text, content: node.value))
            default:
                // 对于其他类型的节点，保持不变
                tokens.append(FlatToken(type: .other, content: node.value, node: node))
            }
        }
    }
    
    /// 重新构建emphasis结构
    private func rebuildEmphasisStructure(_ parentNode: CodeNode, flatTokens: [FlatToken], marker: String) {
        var tokens = flatTokens
        
        while !tokens.isEmpty {
            if tokens[0].type == .partial && tokens[0].content == marker {
                // 寻找匹配的closing markers
                if let match = findBestEmphasisMatch(tokens, startIndex: 0, marker: marker) {
                    print("找到最佳匹配: start=0, end=\(match.endIndex), count=\(match.count)")
                    
                    // 创建emphasis节点
                    let contentTokens = Array(tokens[match.count..<match.endIndex])
                    let emphasisNode = createEmphasisFromTokens(contentTokens, matchCount: match.count, marker: marker)
                    parentNode.addChild(emphasisNode)
                    
                    // 移除已处理的tokens
                    tokens.removeSubrange(0...(match.endIndex + match.count - 1))
                } else {
                    // 没有匹配，作为partial保留
                    let partialNode = CodeNode(
                        type: MarkdownElement.partialEmphasis,
                        value: marker,
                        range: "".startIndex..<"".endIndex
                    )
                    parentNode.addChild(partialNode)
                    tokens.removeFirst()
                }
            } else {
                // 非partial token，直接添加
                if tokens[0].type == .text {
                    let textNode = CodeNode(
                        type: MarkdownElement.text,
                        value: tokens[0].content,
                        range: "".startIndex..<"".endIndex
                    )
                    parentNode.addChild(textNode)
                } else if tokens[0].type == .other, let node = tokens[0].node {
                    parentNode.addChild(node)
                }
                tokens.removeFirst()
            }
        }
    }
    
    /// 执行本地重组
    private func performLocalReorganization(_ parentNode: CodeNode, marker: String) {
        // 多轮重组，直到没有更多的重组机会
        var hasChanges = true
        let maxIterations = 5  // 防止无限循环
        var iteration = 0
        
        while hasChanges && iteration < maxIterations {
            hasChanges = false
            iteration += 1
            
            print("第\(iteration)轮重组")
            
            // 收集所有partial emphasis和其他节点的信息
            var nodeInfo: [(node: CodeNode, index: Int, isPartial: Bool, markerCount: Int)] = []
            
            for (index, child) in parentNode.children.enumerated() {
                if let element = child.type as? MarkdownElement,
                   element == .partialEmphasis,
                   child.value == marker {
                    nodeInfo.append((node: child, index: index, isPartial: true, markerCount: 1))
                } else {
                    nodeInfo.append((node: child, index: index, isPartial: false, markerCount: 0))
                }
            }
            
            // 合并连续的partial nodes
            let groupedInfo = groupConsecutivePartials(nodeInfo)
            print("分组后: \(groupedInfo.count) 组")
            
            // 尝试寻找最佳的emphasis配对
            if let bestReorganization = findBestEmphasisReorganization(groupedInfo, marker: marker) {
                print("找到最佳重组方案，应用重组")
                applyEmphasisReorganization(parentNode, reorganization: bestReorganization)
                hasChanges = true
            } else {
                print("未找到可重组的emphasis结构")
            }
        }
    }
    
    /// 将连续的partial nodes分组
    private func groupConsecutivePartials(_ nodeInfo: [(node: CodeNode, index: Int, isPartial: Bool, markerCount: Int)]) -> [NodeGroup] {
        var groups: [NodeGroup] = []
        var currentGroup: NodeGroup? = nil
        
        for info in nodeInfo {
            if info.isPartial {
                if currentGroup == nil || currentGroup!.type != .partial {
                    // 开始新的partial组
                    currentGroup = NodeGroup(type: .partial, startIndex: info.index, endIndex: info.index, nodes: [info.node], markerCount: 1)
                } else {
                    // 扩展当前partial组
                    currentGroup!.endIndex = info.index
                    currentGroup!.nodes.append(info.node)
                    currentGroup!.markerCount += 1
                }
            } else {
                // 完成当前partial组
                if let group = currentGroup {
                    groups.append(group)
                    currentGroup = nil
                }
                
                // 添加内容组
                groups.append(NodeGroup(type: .content, startIndex: info.index, endIndex: info.index, nodes: [info.node], markerCount: 0))
            }
        }
        
        // 完成最后的partial组
        if let group = currentGroup {
            groups.append(group)
        }
        
        return groups
    }
    
    /// 寻找最佳的emphasis重组方案 - 优先选择更大的匹配
    private func findBestEmphasisReorganization(_ groups: [NodeGroup], marker: String) -> EmphasisReorganization? {
        // 找到所有的partial组
        let partialGroups = groups.enumerated().compactMap { index, group in
            group.type == .partial ? (index: index, group: group) : nil
        }
        
        if partialGroups.count < 2 {
            return nil // 需要至少2个partial组才能形成emphasis
        }
        
        var bestReorganization: EmphasisReorganization? = nil
        var bestScore = 0
        
        // 尝试从最后一个partial组开始，向前寻找匹配
        for endIndex in stride(from: partialGroups.count - 1, through: 1, by: -1) {
            let endGroup = partialGroups[endIndex]
            
            for startIndex in stride(from: endIndex - 1, through: 0, by: -1) {
                let startGroup = partialGroups[startIndex]
                
                // 检查是否可以匹配
                let matchCount = min(startGroup.group.markerCount, endGroup.group.markerCount)
                if matchCount > 0 {
                    // 收集两个partial组之间的内容
                    let contentStart = startGroup.index + 1
                    let contentEnd = endGroup.index - 1
                    
                    var contentGroups: [NodeGroup] = []
                    if contentEnd >= contentStart {
                        contentGroups = Array(groups[contentStart...contentEnd])
                    }
                    
                    // 计算分数：优先选择更大的matchCount，然后考虑内容的复杂度
                    let score = matchCount * 100 + contentGroups.count
                    
                    print("评估匹配: start=\(startGroup.group.markerCount), end=\(endGroup.group.markerCount), match=\(matchCount), score=\(score)")
                    
                    if score > bestScore {
                        bestScore = score
                        bestReorganization = EmphasisReorganization(
                            startGroup: startGroup,
                            endGroup: endGroup,
                            contentGroups: contentGroups,
                            matchCount: matchCount,
                            marker: marker
                        )
                    }
                }
            }
        }
        
        if let best = bestReorganization {
            print("选择最佳匹配: matchCount=\(best.matchCount), score=\(bestScore)")
        }
        
        return bestReorganization
    }
    
    /// 应用emphasis重组
    private func applyEmphasisReorganization(_ parentNode: CodeNode, reorganization: EmphasisReorganization) {
        // 收集所有要重组的内容节点
        var contentNodes: [CodeNode] = []
        for group in reorganization.contentGroups {
            contentNodes.append(contentsOf: group.nodes)
        }
        
        print("重组内容节点数量: \(contentNodes.count)")
        
        // 创建emphasis节点
        let emphasisNode = createEmphasisNode(
            matchCount: reorganization.matchCount,
            contentNodes: contentNodes,
            range: "".startIndex..<"".endIndex
        )
        
        // 计算要移除的所有索引
        var indicesToRemove: Set<Int> = Set()
        
        // 添加起始组的索引
        for i in reorganization.startGroup.group.startIndex...reorganization.startGroup.group.endIndex {
            indicesToRemove.insert(i)
        }
        
        // 添加内容组的索引
        for group in reorganization.contentGroups {
            for i in group.startIndex...group.endIndex {
                indicesToRemove.insert(i)
            }
        }
        
        // 添加结束组的索引
        for i in reorganization.endGroup.group.startIndex...reorganization.endGroup.group.endIndex {
            indicesToRemove.insert(i)
        }
        
        // 从后往前移除节点（避免索引变化）
        for index in indicesToRemove.sorted(by: >) {
            if index < parentNode.children.count {
                parentNode.children.remove(at: index)
            }
        }
        
        // 在原位置插入emphasis节点
        let insertIndex = reorganization.startGroup.group.startIndex
        if insertIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: insertIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // 处理剩余的partial markers
        let remainingStart = reorganization.startGroup.group.markerCount - reorganization.matchCount
        let remainingEnd = reorganization.endGroup.group.markerCount - reorganization.matchCount
        
        print("剩余markers: start=\(remainingStart), end=\(remainingEnd)")
        
        // 添加剩余的partial nodes
        for i in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: reorganization.marker,
                range: "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: insertIndex + i)
        }
        
        let finalEmphasisIndex = insertIndex + remainingStart
        for i in 0..<remainingEnd {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: reorganization.marker,
                range: "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: finalEmphasisIndex + 1 + i)
        }
    }
    
    /// 计算剩余tokens中指定marker的数量
    private func countRemainingMarkers(in tokens: [CodeToken], marker: String) -> Int {
        var count = 0
        for token in tokens {
            if let mdToken = token as? MarkdownToken,
               mdToken.text == marker,
               ((marker == "*" && mdToken.kind == .asterisk) || (marker == "_" && mdToken.kind == .underscore)) {
                count += 1
            }
        }
        return count
    }
    
    /// 查找partial emphasis选项
    private func findPartialEmphasisOptions(in parentNode: CodeNode, marker: String) -> [(index: Int, consecutiveCount: Int)] {
        var options: [(index: Int, consecutiveCount: Int)] = []
        
        var i = 0
        while i < parentNode.children.count {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // 计算从这个位置开始的连续partial数量
                var consecutiveCount = 0
                var checkIndex = i
                
                while checkIndex < parentNode.children.count,
                      let checkElement = parentNode.children[checkIndex].type as? MarkdownElement,
                      checkElement == .partialEmphasis,
                      parentNode.children[checkIndex].value == marker {
                    consecutiveCount += 1
                    checkIndex += 1
                }
                
                options.append((index: i, consecutiveCount: consecutiveCount))
                i = checkIndex  // 跳过已检查的连续partial
            } else {
                i += 1
            }
        }
        
        return options
    }
    
    /// 执行正常的匹配流程
    private func performNormalMatch(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        let matchOptions = findPartialEmphasisOptions(in: parentNode, marker: marker)
        
        if matchOptions.isEmpty {
            return false
        }
        
        print("找到匹配选项: \(matchOptions)")
        
        // 选择最远的完全匹配选项
        let sortedOptions = matchOptions.sorted { $0.index < $1.index }
        
        for option in sortedOptions {
            let possibleMatch = min(option.consecutiveCount, count)
            
            if possibleMatch == count {
                let contentStart = option.index + option.consecutiveCount
                let hasContent = contentStart < parentNode.children.count
                
                if hasContent {
                    print("选择最远的完全匹配选项: index=\(option.index), count=\(option.consecutiveCount)")
                    return executeEmphasisMatch(
                        context: &context,
                        startIndex: option.index,
                        availableCount: option.consecutiveCount,
                        matchCount: possibleMatch,
                        endCount: count,
                        marker: marker
                    )
                }
            }
        }
        
        print("没有找到合适的匹配")
        return false
    }
    
    /// 尝试最佳匹配策略
    private func tryBestMatchStrategy(
        context: inout CodeContext,
        marker: String,
        count: Int,
        options: [(index: Int, consecutiveCount: Int)]
    ) -> Bool {
        // 策略1：优先匹配能够完全匹配且距离最远的选项（形成最外层的结构）
        // 按index排序，优先选择距离最远的匹配
        let sortedOptions = options.sorted { $0.index < $1.index }
        
        for option in sortedOptions {
            let possibleMatch = min(option.consecutiveCount, count)
            
            if possibleMatch == count {
                let contentStart = option.index + option.consecutiveCount
                let hasContent = contentStart < context.currentNode.children.count
                
                if hasContent {
                    print("选择最远的完全匹配选项: index=\(option.index), count=\(option.consecutiveCount)")
                    return executeEmphasisMatch(
                        context: &context,
                        startIndex: option.index,
                        availableCount: option.consecutiveCount,
                        matchCount: possibleMatch,
                        endCount: count,
                        marker: marker
                    )
                }
            }
        }
        
        // 策略2：如果没有完全匹配，检查是否应该等待更好的匹配
        // 特殊逻辑：如果当前markers数量 >= 2，我们倾向于等待而不是匹配单个marker
        if count >= 2 {
            // 检查是否有单个marker的选项
            let hasMultipleMarkerOptions = options.contains { $0.consecutiveCount >= count }
            
            if !hasMultipleMarkerOptions {
                // 如果没有足够的开始markers匹配，等待
                print("等待更好匹配：需要\(count)个markers但没有足够的开始markers")
                return false
            }
        }
        
        print("没有找到合适的匹配策略")
        return false
    }
    
    /// 执行emphasis匹配
    private func executeEmphasisMatch(
        context: inout CodeContext,
        startIndex: Int,
        availableCount: Int,
        matchCount: Int,
        endCount: Int,
        marker: String
    ) -> Bool {
        let parentNode = context.currentNode
        
        // 收集内容节点
        let contentStart = startIndex + availableCount
        var contentNodes: [CodeNode] = []
        
        for i in contentStart..<parentNode.children.count {
            contentNodes.append(parentNode.children[i])
        }
        
        print("收集\(contentNodes.count)个内容节点用于emphasis")
        
        // 移除内容节点（从后往前）
        for i in (contentStart..<parentNode.children.count).reversed() {
            parentNode.children[i].removeFromParent()
        }
        
        // 移除匹配的partial nodes（从后往前）
        let removeEnd = startIndex + matchCount
        for i in (startIndex..<removeEnd).reversed() {
            parentNode.children[i].removeFromParent()
        }
        
        // 创建emphasis节点
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: "".startIndex..<"".endIndex
        )
        
        // 插入emphasis节点
        parentNode.insertChild(emphasisNode, at: startIndex)
        
        // 处理剩余的markers
        let remainingStart = availableCount - matchCount
        let remainingEnd = endCount - matchCount
        
        // 在emphasis前插入剩余的开始partial
        for i in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + i)
        }
        
        // 在emphasis后插入剩余的结束partial
        let emphasisIndex = startIndex + remainingStart
        for i in 0..<remainingEnd {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: emphasisIndex + 1 + i)
        }
        
        return true
    }
    
    /// 智能匹配策略：优先考虑能形成有效嵌套结构的匹配
    private func trySmartMatch(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        
        // 找到所有可能的匹配组合
        var partialRanges: [(start: Int, count: Int)] = []
        
        var i = 0
        while i < parentNode.children.count {
            let child = parentNode.children[i]
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // 计算连续的partial数量
                var consecutiveCount = 0
                var j = i
                while j < parentNode.children.count {
                    let checkChild = parentNode.children[j]
                    if let checkElement = checkChild.type as? MarkdownElement,
                       checkElement == .partialEmphasis,
                       checkChild.value == marker {
                        consecutiveCount += 1
                        j += 1
                    } else {
                        break
                    }
                }
                
                partialRanges.append((start: i, count: consecutiveCount))
                i = j
            } else {
                i += 1
            }
        }
        
        // 如果没有partial nodes，不能匹配
        guard !partialRanges.isEmpty else {
            return false
        }
        
        // 尝试找到最佳匹配：优先匹配能够完全消耗markers的组合
        for range in partialRanges.reversed() {  // 从后往前优先
            let matchCount = min(range.count, count)
            if matchCount > 0 {
                return executeMatch(
                    context: &context,
                    startIndex: range.start,
                    availableCount: range.count,
                    matchCount: matchCount,
                    endCount: count,
                    marker: marker
                )
            }
        }
        
        return false
    }
    
    /// 执行匹配操作
    private func executeMatch(
        context: inout CodeContext,
        startIndex: Int,
        availableCount: Int,
        matchCount: Int,
        endCount: Int,
        marker: String
    ) -> Bool {
        let parentNode = context.currentNode
        
        // 收集内容节点
        let contentStart = startIndex + availableCount
        let contentEnd = parentNode.children.count
        
        var contentNodes: [CodeNode] = []
        for j in contentStart..<contentEnd {
            contentNodes.append(parentNode.children[j])
        }
        
        // 创建emphasis节点
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[startIndex].range ?? "".startIndex..<"".endIndex
        )
        
        // 移除内容节点（从后往前）
        for j in (contentStart..<contentEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // 移除匹配的partial nodes（从后往前）
        let removeEnd = startIndex + matchCount
        for j in (startIndex..<removeEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // 在原位置插入emphasis节点
        if startIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: startIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // 处理剩余的markers
        let remainingStart = availableCount - matchCount
        let remainingEnd = endCount - matchCount
        
        // 在emphasis前插入剩余的开始partial
        for j in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + j)
        }
        
        // 在emphasis后插入剩余的结束partial
        let finalEmphasisIndex = startIndex + remainingStart
        for j in 0..<remainingEnd {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: finalEmphasisIndex + 1 + j)
        }
        
        return true
    }
    
    /// 尝试匹配现有的partial emphasis
    private func tryMatchExistingPartials(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        
        // 收集所有可能的匹配选项
        var matchOptions: [(startIndex: Int, availableCount: Int)] = []
        
        var i = parentNode.children.count - 1
        while i >= 0 {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // 计算这个位置向前的连续partial数量
                var existingCount = 0
                var startIndex = i
                
                while startIndex >= 0 {
                    let checkChild = parentNode.children[startIndex]
                    if let checkElement = checkChild.type as? MarkdownElement,
                       checkElement == .partialEmphasis,
                       checkChild.value == marker {
                        existingCount += 1
                        startIndex -= 1
                    } else {
                        break
                    }
                }
                
                startIndex += 1  // 调整到实际开始位置
                matchOptions.append((startIndex: startIndex, availableCount: existingCount))
                
                // 跳过已经检查过的partial nodes
                i = startIndex - 1
            } else {
                i -= 1
            }
        }
        
        // 选择最佳匹配：选择最近的能够匹配的选项
        var bestMatch: (startIndex: Int, availableCount: Int, matchCount: Int)? = nil
        
        // 从最近的选项开始查找（从后往前）
        for option in matchOptions {
            let possibleMatch = min(option.availableCount, count)
            if possibleMatch > 0 {
                bestMatch = (option.startIndex, option.availableCount, possibleMatch)
                break  // 选择第一个（最近的）可匹配选项
            }
        }
        
        guard let match = bestMatch else {
            return false
        }
        
        // 执行匹配
        let startIndex = match.startIndex
        let matchCount = match.matchCount
        
        // 收集内容节点
        let contentStart = startIndex + match.availableCount
        let contentEnd = parentNode.children.count
        
        var contentNodes: [CodeNode] = []
        for j in contentStart..<contentEnd {
            contentNodes.append(parentNode.children[j])
        }
        
        // 创建emphasis节点
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[startIndex].range ?? "".startIndex..<"".endIndex
        )
        
        // 移除内容节点（从后往前）
        for j in (contentStart..<contentEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // 移除匹配的partial nodes（从后往前）
        let removeEnd = startIndex + matchCount
        for j in (startIndex..<removeEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // 在原位置插入emphasis节点
        if startIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: startIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // 处理剩余的markers
        let remainingStart = match.availableCount - matchCount
        let remainingEnd = count - matchCount
        
        // 在emphasis前插入剩余的开始partial
        for j in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + j)
        }
        
        // 在emphasis后插入剩余的结束partial
        let finalEmphasisIndex = startIndex + remainingStart
        for j in 0..<remainingEnd {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: finalEmphasisIndex + 1 + j)
        }
        
        return true
    }
    
    /// 检查并解析可以确定语义的partial emphasis - 使用右优先匹配
    private func resolvePartialEmphasisIfPossible(context: inout CodeContext, marker: String) {
        let parentNode = context.currentNode
        
        print("resolvePartialEmphasisIfPossible: marker='\(marker)', children=\(parentNode.children.map { ($0.type as? MarkdownElement)?.description ?? "unknown" })")
        
        // 从后往前查找partial emphasis，实现右优先匹配
        var i = parentNode.children.count - 1
        while i >= 0 {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                print("找到partial emphasis at index \(i)")
                
                // 找到一个partial emphasis，向前查找匹配的开始partial
                if let matchResult = findMatchingPartialEmphasisBackward(in: parentNode, endIndex: i, marker: marker) {
                    print("找到匹配: \(matchResult)")
                    // 执行替换
                    replacePartialWithEmphasis(in: parentNode, matchResult: matchResult)
                    
                    // 重新开始扫描，因为节点结构已改变
                    i = parentNode.children.count - 1
                    continue
                }
            }
            
            i -= 1
        }
    }
    
    /// 从结束位置向前查找匹配的partial emphasis
    private func findMatchingPartialEmphasisBackward(in parentNode: CodeNode, endIndex: Int, marker: String) -> EmphasisMatchResult? {
        
        // 计算结束位置的连续partial数量（向前计算）
        var endCount = 0
        var currentIndex = endIndex
        
        while currentIndex >= 0 {
            let child = parentNode.children[currentIndex]
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                endCount += 1
                currentIndex -= 1
            } else {
                break
            }
        }
        
        let endStartIndex = currentIndex + 1  // 结束partial序列的开始位置
        let contentEnd = endStartIndex        // 内容的结束位置
        
        // 向前查找匹配的开始partial emphasis
        while currentIndex >= 0 {
            let child = parentNode.children[currentIndex]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // 计算这个位置向前的连续partial数量
                var startCount = 0
                var tempIndex = currentIndex
                
                while tempIndex >= 0 {
                    let tempChild = parentNode.children[tempIndex]
                    if let tempElement = tempChild.type as? MarkdownElement,
                       tempElement == .partialEmphasis,
                       tempChild.value == marker {
                        startCount += 1
                        tempIndex -= 1
                    } else {
                        break
                    }
                }
                
                let startIndex = tempIndex + 1
                let contentStart = startIndex + startCount
                
                // 检查是否可以匹配
                let matchCount = min(startCount, endCount)
                if matchCount > 0 && contentStart < contentEnd {
                    return EmphasisMatchResult(
                        startIndex: startIndex,
                        startCount: startCount,
                        contentStart: contentStart,
                        contentEnd: contentEnd,
                        endIndex: endStartIndex,
                        endCount: endCount,
                        matchCount: matchCount,
                        marker: marker
                    )
                }
                
                currentIndex = tempIndex
            } else {
                currentIndex -= 1
            }
        }
        
        return nil
    }
    
    /// 将匹配的partial emphasis替换为最终的emphasis节点
    private func replacePartialWithEmphasis(in parentNode: CodeNode, matchResult: EmphasisMatchResult) {
        // 收集内容节点
        var contentNodes: [CodeNode] = []
        for i in matchResult.contentStart..<matchResult.contentEnd {
            contentNodes.append(parentNode.children[i])
        }
        
        // 创建emphasis节点
        let emphasisNode = createEmphasisNode(
            matchCount: matchResult.matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[matchResult.startIndex].range ?? contentNodes.first?.range ?? "".startIndex..<"".endIndex
        )
        
        // 移除结束partial nodes（从后往前）
        let endRemoveStart = matchResult.endIndex
        let endRemoveEnd = matchResult.endIndex + matchResult.matchCount
        for i in (endRemoveStart..<endRemoveEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // 移除内容nodes（从后往前）
        for i in (matchResult.contentStart..<matchResult.contentEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // 移除匹配的开始partial nodes（从后往前）
        let startRemoveEnd = matchResult.startIndex + matchResult.matchCount
        for i in (matchResult.startIndex..<startRemoveEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // 在原位置插入emphasis节点
        let insertIndex = matchResult.startIndex
        if insertIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: insertIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // 处理剩余的partial nodes
        let remainingStart = matchResult.startCount - matchResult.matchCount
        let remainingEnd = matchResult.endCount - matchResult.matchCount
        
        // 在emphasis前插入剩余的开始partial
        for i in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: matchResult.marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: insertIndex + i)
        }
        
        // 在emphasis后插入剩余的结束partial
        let finalEmphasisIndex = insertIndex + remainingStart
        for i in 0..<remainingEnd {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: matchResult.marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: finalEmphasisIndex + 1 + i)
        }
    }
    
    /// 创建emphasis节点（内容仅通过children表示）
    private func createEmphasisNode(matchCount: Int, contentNodes: [CodeNode], range: Range<String.Index>) -> CodeNode {
        if matchCount >= 3 {
            // ***text*** -> strongEmphasis with nested emphasis
            let strongNode = CodeNode(type: MarkdownElement.strongEmphasis, value: "", range: range)
            let emphasisNode = CodeNode(type: MarkdownElement.emphasis, value: "", range: range)
            
            // 将内容节点添加到emphasis节点
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                emphasisNode.addChild(contentNode)
            }
            
            strongNode.addChild(emphasisNode)
            return strongNode
            
        } else if matchCount >= 2 {
            // **text** -> strongEmphasis
            let strongNode = CodeNode(type: MarkdownElement.strongEmphasis, value: "", range: range)
            
            // 将内容节点添加到strong节点
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                strongNode.addChild(contentNode)
            }
            
            return strongNode
            
        } else {
            // *text* -> emphasis
            let emphasisNode = CodeNode(type: MarkdownElement.emphasis, value: "", range: range)
            
            // 将内容节点添加到emphasis节点
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                emphasisNode.addChild(contentNode)
            }
            
            return emphasisNode
        }
    }
    
    /// 后处理partial emphasis，在解析完成后调用
    func postProcessPartialEmphasis(_ node: CodeNode) {
        // 分析所有的partial emphasis并尝试匹配
        resolveAllPartialEmphasis(node)
    }
    
    /// 解析节点中所有的partial emphasis
    private func resolveAllPartialEmphasis(_ node: CodeNode) {
        var changed = true
        
        // 重复处理直到没有变化
        while changed {
            changed = false
            
            // 查找可以匹配的emphasis对
            for marker in ["*", "_"] {
                if findAndResolveEmphasisPair(node, marker: marker) {
                    changed = true
                    break
                }
            }
        }
    }
    
    /// 查找并解析一对emphasis markers
    private func findAndResolveEmphasisPair(_ node: CodeNode, marker: String) -> Bool {
        var openPositions: [Int] = []
        var closePosition: Int? = nil
        
        // 从前往后扫描，查找开启markers，从后往前查找第一个可以匹配的
        for (i, child) in node.children.enumerated() {
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // 检查这个位置后面是否有非partial的内容
                let hasContentAfter = i + 1 < node.children.count && 
                                    !(node.children[i + 1].type is MarkdownElement && 
                                      (node.children[i + 1].type as! MarkdownElement) == .partialEmphasis)
                
                if hasContentAfter && openPositions.isEmpty {
                    // 这是一个潜在的开始marker
                    openPositions.append(i)
                } else if !openPositions.isEmpty {
                    // 这是一个潜在的结束marker
                    closePosition = i
                    break
                }
            }
        }
        
        // 如果找到了匹配对，创建emphasis
        if let closePos = closePosition, !openPositions.isEmpty {
            let openPos = openPositions.last!
            
            // 收集内容节点
            var contentNodes: [CodeNode] = []
            for i in (openPos + 1)..<closePos {
                contentNodes.append(node.children[i])
            }
            
            // 创建emphasis节点
            let emphasisNode = CodeNode(
                type: MarkdownElement.emphasis,
                value: "",
                range: node.children[openPos].range ?? "".startIndex..<"".endIndex
            )
            
            // 移除原节点并重新组织
            // 从后往前移除，避免索引混乱
            for i in (openPos...closePos).reversed() {
                node.children[i].removeFromParent()
            }
            
            // 添加内容到emphasis节点
            for contentNode in contentNodes {
                emphasisNode.addChild(contentNode)
            }
            
            // 在原位置插入emphasis节点
            node.insertChild(emphasisNode, at: openPos)
            
            return true
        }
        
        return false
    }
    
    /// 寻找最佳的emphasis匹配 - 优先选择更大的匹配
    private func findBestEmphasisMatch(_ tokens: [FlatToken], startIndex: Int, marker: String) -> EmphasisMatch? {
        var i = startIndex
        var startCount = 0
        
        // 计算起始markers的数量
        while i < tokens.count && tokens[i].type == .partial && tokens[i].content == marker {
            startCount += 1
            i += 1
        }
        
        if startCount == 0 {
            return nil
        }
        
        // 收集所有可能的匹配
        var possibleMatches: [EmphasisMatch] = []
        let contentStart = i
        var searchIndex = contentStart
        
        while searchIndex < tokens.count {
            if tokens[searchIndex].type == .partial && tokens[searchIndex].content == marker {
                // 计算结束markers的数量
                var endCount = 0
                var tempIndex = searchIndex
                
                while tempIndex < tokens.count && tokens[tempIndex].type == .partial && tokens[tempIndex].content == marker {
                    endCount += 1
                    tempIndex += 1
                }
                
                // 计算可能的匹配
                for matchCount in 1...min(startCount, endCount) {
                    possibleMatches.append(EmphasisMatch(endIndex: searchIndex, count: matchCount))
                }
                
                searchIndex = tempIndex
            } else {
                searchIndex += 1
            }
        }
        
        if possibleMatches.isEmpty {
            return nil
        }
        
        // 选择最佳匹配：优先选择最大的matchCount
        let bestMatch = possibleMatches.max { match1, match2 in
            if match1.count != match2.count {
                return match1.count < match2.count  // 优先选择更大的count
            }
            // 如果count相同，选择距离更远的（包含更多内容）
            return match1.endIndex < match2.endIndex
        }
        
        print("评估了\(possibleMatches.count)个可能的匹配，选择: count=\(bestMatch?.count ?? 0)")
        
        return bestMatch
    }
    
    /// 从tokens创建emphasis节点
    private func createEmphasisFromTokens(_ tokens: [FlatToken], matchCount: Int, marker: String) -> CodeNode {
        let emphasisType: MarkdownElement = matchCount >= 2 ? .strongEmphasis : .emphasis
        let emphasisNode = CodeNode(
            type: emphasisType,
            value: "",
            range: "".startIndex..<"".endIndex
        )
        
        var i = 0
        while i < tokens.count {
            if tokens[i].type == .partial && tokens[i].content == marker {
                // 递归处理嵌套emphasis
                if let nestedMatch = findBestEmphasisMatch(tokens, startIndex: i, marker: marker) {
                    let contentTokens = Array(tokens[(i + nestedMatch.count)..<nestedMatch.endIndex])
                    let nestedNode = createEmphasisFromTokens(contentTokens, matchCount: nestedMatch.count, marker: marker)
                    emphasisNode.addChild(nestedNode)
                    i = nestedMatch.endIndex + nestedMatch.count
                } else {
                    // 作为partial保留
                    let partialNode = CodeNode(
                        type: MarkdownElement.partialEmphasis,
                        value: marker,
                        range: "".startIndex..<"".endIndex
                    )
                    emphasisNode.addChild(partialNode)
                    i += 1
                }
            } else if tokens[i].type == .text {
                let textNode = CodeNode(
                    type: MarkdownElement.text,
                    value: tokens[i].content,
                    range: "".startIndex..<"".endIndex
                )
                emphasisNode.addChild(textNode)
                i += 1
            } else if tokens[i].type == .other, let node = tokens[i].node {
                emphasisNode.addChild(node)
                i += 1
            } else {
                i += 1
            }
        }
        
        return emphasisNode
    }
}

/// 表示emphasis匹配结果的结构
private struct EmphasisMatchResult {
    let startIndex: Int      // 开始partial nodes的位置
    let startCount: Int      // 开始partial nodes的数量
    let contentStart: Int    // 内容开始位置
    let contentEnd: Int      // 内容结束位置
    let endIndex: Int        // 结束partial nodes的位置
    let endCount: Int        // 结束partial nodes的数量
    let matchCount: Int      // 实际匹配的标记数量
    let marker: String       // 标记字符
}

/// 处理内联代码的Consumer
public class MarkdownInlineCodeConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .backtick {
            return consumeInlineCode(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeInlineCode(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst()
        
        var codeText = ""
        var foundClosing = false
        
        // 查找闭合的反引号
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof {
                break
            }
            
            if currentToken.kind == .backtick {
                context.tokens.removeFirst()
                foundClosing = true
                break
            }
            
            codeText += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosing {
            let codeNode = CodeNode(type: MarkdownElement.inlineCode, value: codeText, range: token.range)
            context.currentNode.addChild(codeNode)
            return true
        } else {
            // 没找到闭合标记，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "`" + codeText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

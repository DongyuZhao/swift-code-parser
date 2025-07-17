import Foundation

/// Consumer for handling headers, supports ATX headers (# Header)
public class MarkdownHeaderConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if this is a # character at the beginning of a line
        if mdToken.kind == .hash && mdToken.isAtLineStart {
            return consumeAtxHeader(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeAtxHeader(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // Remove current # token
        context.tokens.removeFirst()
        
        // Calculate header level
        var level = 1
        var headerText = ""
        
        // Consume consecutive # characters
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind == .hash {
            level += 1
            context.tokens.removeFirst()
            
            // Maximum 6 levels of headers supported
            if level > 6 {
                level = 6
                break
            }
        }
        
        // Skip whitespace
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind == .whitespace {
            context.tokens.removeFirst()
        }
        
        // Collect header text until end of line
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.kind != .newline && nextToken.kind != .eof {
            headerText += nextToken.text
            context.tokens.removeFirst()
        }
        
        // Remove trailing # characters and whitespace
        headerText = headerText.trimmingCharacters(in: .whitespaces)
        if headerText.hasSuffix("#") {
            headerText = String(headerText.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        // Create header node for the corresponding level
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

/// Consumer for handling paragraphs
public class MarkdownParagraphConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // If it's a text token, start a paragraph
        if mdToken.kind == .text && mdToken.isAtLineStart {
            return consumeParagraph(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeParagraph(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // Create paragraph node
        let paragraphNode = CodeNode(type: MarkdownElement.paragraph, value: "", range: token.range)
        context.currentNode.addChild(paragraphNode)
        
        // Enter paragraph context
        let previousNode = context.currentNode
        context.currentNode = paragraphNode
        
        var paragraphText = ""
        
        // Collect paragraph content until encountering blank line or block-level element
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof {
                break
            }
            
            if currentToken.kind == .newline {
                context.tokens.removeFirst()
                
                // Check if next line is blank or starts with block-level element
                if let nextToken = context.tokens.first as? MarkdownToken {
                    if nextToken.kind == .newline || isBlockElementStart(nextToken) {
                        break
                    }
                    // If not a blank line, add space
                    paragraphText += " "
                }
                continue
            }
            
            // Try to let inline consumers handle this token
            var consumed = false
            for inlineConsumer in getInlineConsumers() {
                if inlineConsumer.consume(context: &context, token: currentToken) {
                    consumed = true
                    break
                }
            }
            
            // If no inline consumer handled it, add to paragraph text
            if !consumed {
                paragraphText += currentToken.text
                context.tokens.removeFirst()
            }
        }
        
        // If there's remaining text, create text node
        if !paragraphText.isEmpty {
            let textNode = CodeNode(type: MarkdownElement.text, value: paragraphText.trimmingCharacters(in: .whitespaces), range: token.range)
            paragraphNode.addChild(textNode)
        }
        
        // Restore context
        context.currentNode = previousNode
        
        // Set paragraph value as the joined text content of all child nodes
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
            MarkdownHTMLInlineConsumer(),
            MarkdownFootnoteReferenceConsumer(),
            MarkdownCitationReferenceConsumer()
        ]
    }
    
    private func isBlockElementStart(_ token: MarkdownToken) -> Bool {
        return token.kind == .hash && token.isAtLineStart ||
               token.kind == .greaterThan && token.isAtLineStart ||
               token.kind == .backtick && token.isAtLineStart ||
               (token.kind == .asterisk || token.kind == .dash || token.kind == .plus) && token.isAtLineStart
    }
}

/// Token type
enum FlatTokenType {
    case partial
    case text
    case other
}

/// Flattened token representation
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

/// Emphasis match result
struct EmphasisMatch {
    let endIndex: Int
    let count: Int
}

/// Node group type
enum NodeGroupType {
    case partial
    case content
}

/// Node group
struct NodeGroup {
    let type: NodeGroupType
    var startIndex: Int
    var endIndex: Int
    var nodes: [CodeNode]
    var markerCount: Int
}

/// Emphasis reorganization plan
struct EmphasisReorganization {
    let startGroup: (index: Int, group: NodeGroup)
    let endGroup: (index: Int, group: NodeGroup)
    let contentGroups: [NodeGroup]
    let matchCount: Int
    let marker: String
}

/// Consumer for handling emphasis (* and _), using backtrack reorganization strategy
public class MarkdownEmphasisConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .asterisk || mdToken.kind == .underscore {
            return handleEmphasisToken(context: &context, token: mdToken)
        }
        
        return false
    }
    
    /// Handle emphasis token - using backtrack reorganization strategy
    private func handleEmphasisToken(context: inout CodeContext, token: MarkdownToken) -> Bool {
        let marker = token.text
        
        // First remove current token and calculate consecutive marker count
        context.tokens.removeFirst()
        var markerCount = 1
        
        while let nextToken = context.tokens.first as? MarkdownToken,
              nextToken.text == marker,
              ((marker == "*" && nextToken.kind == .asterisk) || (marker == "_" && nextToken.kind == .underscore)) {
            markerCount += 1
            context.tokens.removeFirst()
        }
        
        
        // First add new partial nodes
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
        
        // Then backtrack and reorganize entire AST to find best emphasis structure
        backtrackAndReorganizeEmphasis(context: &context, marker: marker)
        
        return true
    }
    /// Backtrack and reorganize emphasis structure - supports re-evaluating existing structures
    private func backtrackAndReorganizeEmphasis(context: inout CodeContext, marker: String) {
        let parentNode = context.currentNode
        
        
        // If these are newly added partial markers, try global reorganization first
        if shouldPerformGlobalReorganization(parentNode, marker: marker) {
            
            performGlobalReorganization(parentNode, marker: marker)
            return
        }
        
        // Otherwise perform regular multi-round reorganization
        performLocalReorganization(parentNode, marker: marker)
    }
    
    /// Check if global reorganization is needed
    private func shouldPerformGlobalReorganization(_ parentNode: CodeNode, marker: String) -> Bool {
        // Count partial markers and emphasis nodes
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
        
        // If there are multiple partial markers and emphasis nodes, may need global reorganization
        return partialCount >= 2 && emphasisCount > 0
    }
    
    /// Perform global reorganization: flatten all content then re-match
    private func performGlobalReorganization(_ parentNode: CodeNode, marker: String) {
        
        // Collect all original tokens and content
        var flatTokens: [FlatToken] = []
        
        for child in parentNode.children {
            flattenNode(child, into: &flatTokens, marker: marker)
        }
        
        // Clear existing children
        parentNode.children.removeAll()
        
        // Rebuild emphasis structure
        rebuildEmphasisStructure(parentNode, flatTokens: flatTokens, marker: marker)
    }
    
    /// Flatten node to tokens
    private func flattenNode(_ node: CodeNode, into tokens: inout [FlatToken], marker: String) {
        if let element = node.type as? MarkdownElement {
            switch element {
            case .partialEmphasis:
                if node.value == marker {
                    tokens.append(FlatToken(type: .partial, content: marker))
                }
            case .emphasis, .strongEmphasis:
                // Extract emphasis markers and content
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
                // For other types of nodes, keep unchanged
                tokens.append(FlatToken(type: .other, content: node.value, node: node))
            }
        }
    }
    
    /// Rebuild emphasis structure
    private func rebuildEmphasisStructure(_ parentNode: CodeNode, flatTokens: [FlatToken], marker: String) {
        var tokens = flatTokens
        
        while !tokens.isEmpty {
            if tokens[0].type == .partial && tokens[0].content == marker {
                // Find matching closing markers
                if let match = findBestEmphasisMatch(tokens, startIndex: 0, marker: marker) {
                    
                    // Create emphasis node
                    let contentTokens = Array(tokens[match.count..<match.endIndex])
                    let emphasisNode = createEmphasisFromTokens(contentTokens, matchCount: match.count, marker: marker)
                    parentNode.addChild(emphasisNode)
                    
                    // Remove processed tokens
                    tokens.removeSubrange(0...(match.endIndex + match.count - 1))
                } else {
                    // No match found, keep as partial
                    let partialNode = CodeNode(
                        type: MarkdownElement.partialEmphasis,
                        value: marker,
                        range: "".startIndex..<"".endIndex
                    )
                    parentNode.addChild(partialNode)
                    tokens.removeFirst()
                }
            } else {
                // Non-partial token, add directly
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
    
    /// Perform local reorganization
    private func performLocalReorganization(_ parentNode: CodeNode, marker: String) {
        // Multi-round reorganization until no more reorganization opportunities
        var hasChanges = true
        let maxIterations = 5  // Prevent infinite loops
        var iteration = 0
        
        while hasChanges && iteration < maxIterations {
            hasChanges = false
            iteration += 1
            
            
            // Collect information about all partial emphasis and other nodes
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
            
            // Group consecutive partial nodes
            let groupedInfo = groupConsecutivePartials(nodeInfo)
            
            // Try to find best emphasis pairing
            if let bestReorganization = findBestEmphasisReorganization(groupedInfo, marker: marker) {
                
                applyEmphasisReorganization(parentNode, reorganization: bestReorganization)
                hasChanges = true
            } else {
                
            }
        }
    }
    
    /// Group consecutive partial nodes
    private func groupConsecutivePartials(_ nodeInfo: [(node: CodeNode, index: Int, isPartial: Bool, markerCount: Int)]) -> [NodeGroup] {
        var groups: [NodeGroup] = []
        var currentGroup: NodeGroup? = nil
        
        for info in nodeInfo {
            if info.isPartial {
                if currentGroup == nil || currentGroup!.type != .partial {
                    // Start new partial group
                    currentGroup = NodeGroup(type: .partial, startIndex: info.index, endIndex: info.index, nodes: [info.node], markerCount: 1)
                } else {
                    // Extend current partial group
                    currentGroup!.endIndex = info.index
                    currentGroup!.nodes.append(info.node)
                    currentGroup!.markerCount += 1
                }
            } else {
                // Complete current partial group
                if let group = currentGroup {
                    groups.append(group)
                    currentGroup = nil
                }
                
                // Add content group
                groups.append(NodeGroup(type: .content, startIndex: info.index, endIndex: info.index, nodes: [info.node], markerCount: 0))
            }
        }
        
        // Complete last partial group
        if let group = currentGroup {
            groups.append(group)
        }
        
        return groups
    }
    
    /// Find best emphasis reorganization plan - prioritize larger matches
    private func findBestEmphasisReorganization(_ groups: [NodeGroup], marker: String) -> EmphasisReorganization? {
        // Find all partial groups
        let partialGroups = groups.enumerated().compactMap { index, group in
            group.type == .partial ? (index: index, group: group) : nil
        }
        
        if partialGroups.count < 2 {
            return nil // Need at least 2 partial groups to form emphasis
        }
        
        var bestReorganization: EmphasisReorganization? = nil
        var bestScore = 0
        
        // Try starting from last partial group, searching forward
        for endIndex in stride(from: partialGroups.count - 1, through: 1, by: -1) {
            let endGroup = partialGroups[endIndex]
            
            for startIndex in stride(from: endIndex - 1, through: 0, by: -1) {
                let startGroup = partialGroups[startIndex]
                
                // Check if can match
                let matchCount = min(startGroup.group.markerCount, endGroup.group.markerCount)
                if matchCount > 0 {
                    // Collect content between two partial groups
                    let contentStart = startGroup.index + 1
                    let contentEnd = endGroup.index - 1
                    
                    var contentGroups: [NodeGroup] = []
                    if contentEnd >= contentStart {
                        contentGroups = Array(groups[contentStart...contentEnd])
                    }
                    
                    // Calculate score: prioritize larger matchCount, then consider content complexity
                    let score = matchCount * 100 + contentGroups.count
                    
                    
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
        
        return bestReorganization
    }
    
    /// Apply emphasis reorganization
    private func applyEmphasisReorganization(_ parentNode: CodeNode, reorganization: EmphasisReorganization) {
        // Collect all content nodes to reorganize
        var contentNodes: [CodeNode] = []
        for group in reorganization.contentGroups {
            contentNodes.append(contentsOf: group.nodes)
        }
        
        
        // Create emphasis node
        let emphasisNode = createEmphasisNode(
            matchCount: reorganization.matchCount,
            contentNodes: contentNodes,
            range: "".startIndex..<"".endIndex
        )
        
        // Calculate all indices to remove
        var indicesToRemove: Set<Int> = Set()
        
        // Add start group indices
        for i in reorganization.startGroup.group.startIndex...reorganization.startGroup.group.endIndex {
            indicesToRemove.insert(i)
        }
        
        // Add content group indices
        for group in reorganization.contentGroups {
            for i in group.startIndex...group.endIndex {
                indicesToRemove.insert(i)
            }
        }
        
        // Add end group indices
        for i in reorganization.endGroup.group.startIndex...reorganization.endGroup.group.endIndex {
            indicesToRemove.insert(i)
        }
        
        // Remove nodes from back to front (to avoid index changes)
        for index in indicesToRemove.sorted(by: >) {
            if index < parentNode.children.count {
                parentNode.children.remove(at: index)
            }
        }
        
        // Insert emphasis node at original position
        let insertIndex = reorganization.startGroup.group.startIndex
        if insertIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: insertIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // Handle remaining partial markers
        let remainingStart = reorganization.startGroup.group.markerCount - reorganization.matchCount
        let remainingEnd = reorganization.endGroup.group.markerCount - reorganization.matchCount
        
        
        // Add remaining partial nodes
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
    
    /// Calculate remaining markers of specified type in tokens
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
    
    /// Find partial emphasis options
    private func findPartialEmphasisOptions(in parentNode: CodeNode, marker: String) -> [(index: Int, consecutiveCount: Int)] {
        var options: [(index: Int, consecutiveCount: Int)] = []
        
        var i = 0
        while i < parentNode.children.count {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // Count consecutive partials starting from this position
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
                i = checkIndex  // Skip checked consecutive partials
            } else {
                i += 1
            }
        }
        
        return options
    }
    
    /// Execute normal matching process
    private func performNormalMatch(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        let matchOptions = findPartialEmphasisOptions(in: parentNode, marker: marker)
        
        if matchOptions.isEmpty {
            return false
        }
        
        
        // Choose the farthest complete match option
        let sortedOptions = matchOptions.sorted { $0.index < $1.index }
        
        for option in sortedOptions {
            let possibleMatch = min(option.consecutiveCount, count)
            
            if possibleMatch == count {
                let contentStart = option.index + option.consecutiveCount
                let hasContent = contentStart < parentNode.children.count
                
                if hasContent {
                    
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
        
        
        return false
    }
    
    /// Try optimal matching strategy
    private func tryBestMatchStrategy(
        context: inout CodeContext,
        marker: String,
        count: Int,
        options: [(index: Int, consecutiveCount: Int)]
    ) -> Bool {
        // Strategy 1: Prioritize options that can fully match and are farthest (forming outermost structure)
        // Sort by index, prioritize farthest matches
        let sortedOptions = options.sorted { $0.index < $1.index }
        
        for option in sortedOptions {
            let possibleMatch = min(option.consecutiveCount, count)
            
            if possibleMatch == count {
                let contentStart = option.index + option.consecutiveCount
                let hasContent = contentStart < context.currentNode.children.count
                
                if hasContent {
                    
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
        
        // Strategy 2: If no complete match, check if we should wait for better matches
        // Special logic: If current markers count >= 2, we tend to wait rather than match a single marker
        if count >= 2 {
            // Check if there are single marker options
            let hasMultipleMarkerOptions = options.contains { $0.consecutiveCount >= count }
            
            if !hasMultipleMarkerOptions {
                // If not enough start markers to match, wait for better match
                
                return false
            }
        }
        
        
        return false
    }
    
    /// Execute emphasis matching
    private func executeEmphasisMatch(
        context: inout CodeContext,
        startIndex: Int,
        availableCount: Int,
        matchCount: Int,
        endCount: Int,
        marker: String
    ) -> Bool {
        let parentNode = context.currentNode
        
        // Collect content nodes
        let contentStart = startIndex + availableCount
        var contentNodes: [CodeNode] = []
        
        for i in contentStart..<parentNode.children.count {
            contentNodes.append(parentNode.children[i])
        }
        
        
        // Remove content nodes (from back to front)
        for i in (contentStart..<parentNode.children.count).reversed() {
            parentNode.children[i].removeFromParent()
        }
        
        // Remove matched partial nodes (from back to front)
        let removeEnd = startIndex + matchCount
        for i in (startIndex..<removeEnd).reversed() {
            parentNode.children[i].removeFromParent()
        }
        
        // Create emphasis node
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: "".startIndex..<"".endIndex
        )
        
        // Insert emphasis node
        parentNode.insertChild(emphasisNode, at: startIndex)
        
        // Handle remaining markers
        let remainingStart = availableCount - matchCount
        let remainingEnd = endCount - matchCount
        
        // Insert remaining start partials before emphasis
        for i in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + i)
        }
        
        // Insert remaining end partials after emphasis
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
    
    /// Smart matching strategy: prioritize matches that can form effective nested structures
    private func trySmartMatch(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        
        // Find all possible matching combinations
        var partialRanges: [(start: Int, count: Int)] = []
        
        var i = 0
        while i < parentNode.children.count {
            let child = parentNode.children[i]
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // Calculate consecutive partial count
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
        
        // If no partial nodes, cannot match
        guard !partialRanges.isEmpty else {
            return false
        }
        
        // Try to find optimal match: prioritize combinations that can fully consume markers
        for range in partialRanges.reversed() {  // From back to front priority
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
    
    /// Execute matching operation
    private func executeMatch(
        context: inout CodeContext,
        startIndex: Int,
        availableCount: Int,
        matchCount: Int,
        endCount: Int,
        marker: String
    ) -> Bool {
        let parentNode = context.currentNode
        
        // Collect content nodes
        let contentStart = startIndex + availableCount
        let contentEnd = parentNode.children.count
        
        var contentNodes: [CodeNode] = []
        for j in contentStart..<contentEnd {
            contentNodes.append(parentNode.children[j])
        }
        
        // Create emphasis node
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[startIndex].range ?? "".startIndex..<"".endIndex
        )
        
        // Remove content nodes (from back to front)
        for j in (contentStart..<contentEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // Remove matched partial nodes (from back to front)
        let removeEnd = startIndex + matchCount
        for j in (startIndex..<removeEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // Insert emphasis node at original position
        if startIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: startIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // Handle remaining markers
        let remainingStart = availableCount - matchCount
        let remainingEnd = endCount - matchCount
        
        // Insert remaining start partials before emphasis
        for j in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + j)
        }
        
        // Insert remaining end partials after emphasis
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
    
    /// Try to match existing partial emphasis
    private func tryMatchExistingPartials(context: inout CodeContext, marker: String, count: Int) -> Bool {
        let parentNode = context.currentNode
        
        // Collect all possible matching options
        var matchOptions: [(startIndex: Int, availableCount: Int)] = []
        
        var i = parentNode.children.count - 1
        while i >= 0 {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // Calculate consecutive partial count forward from this position
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
                
                startIndex += 1  // Adjust to actual start position
                matchOptions.append((startIndex: startIndex, availableCount: existingCount))
                
                // Skip already checked partial nodes
                i = startIndex - 1
            } else {
                i -= 1
            }
        }
        
        // Choose best match: select nearest matchable option
        var bestMatch: (startIndex: Int, availableCount: Int, matchCount: Int)? = nil
        
        // Search from nearest option (from back to front)
        for option in matchOptions {
            let possibleMatch = min(option.availableCount, count)
            if possibleMatch > 0 {
                bestMatch = (option.startIndex, option.availableCount, possibleMatch)
                break  // Choose first (nearest) matchable option
            }
        }
        
        guard let match = bestMatch else {
            return false
        }
        
        // Execute match
        let startIndex = match.startIndex
        let matchCount = match.matchCount
        
        // Collect content nodes
        let contentStart = startIndex + match.availableCount
        let contentEnd = parentNode.children.count
        
        var contentNodes: [CodeNode] = []
        for j in contentStart..<contentEnd {
            contentNodes.append(parentNode.children[j])
        }
        
        // Create emphasis node
        let emphasisNode = createEmphasisNode(
            matchCount: matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[startIndex].range ?? "".startIndex..<"".endIndex
        )
        
        // Remove content nodes (from back to front)
        for j in (contentStart..<contentEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // Remove matched partial nodes (from back to front)
        let removeEnd = startIndex + matchCount
        for j in (startIndex..<removeEnd).reversed() {
            if j < parentNode.children.count {
                parentNode.children[j].removeFromParent()
            }
        }
        
        // Insert emphasis node at original position
        if startIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: startIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // Handle remaining markers
        let remainingStart = match.availableCount - matchCount
        let remainingEnd = count - matchCount
        
        // Insert remaining start partials before emphasis
        for j in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: startIndex + j)
        }
        
        // Insert remaining end partials after emphasis
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
    
    /// Check and resolve semantic partial emphasis - right-priority matching
    private func resolvePartialEmphasisIfPossible(context: inout CodeContext, marker: String) {
        let parentNode = context.currentNode
        
        
        // Search partial emphasis from back to front for right-priority matching
        var i = parentNode.children.count - 1
        while i >= 0 {
            let child = parentNode.children[i]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                
                // Found a partial emphasis, search backward for matching start partial
                if let matchResult = findMatchingPartialEmphasisBackward(in: parentNode, endIndex: i, marker: marker) {
                    
                    // Execute replacement
                    replacePartialWithEmphasis(in: parentNode, matchResult: matchResult)
                    
                    // Restart scanning as node structure changed
                    i = parentNode.children.count - 1
                    continue
                }
            }
            
            i -= 1
        }
    }
    
    /// Search for matching partial emphasis backward from end position
    private func findMatchingPartialEmphasisBackward(in parentNode: CodeNode, endIndex: Int, marker: String) -> EmphasisMatchResult? {
        
        // Calculate number of consecutive partials at end position (backward)
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
        
        let endStartIndex = currentIndex + 1  // Start position of ending partial sequence
        let contentEnd = endStartIndex        // End position for content
        
        // Search backward for matching start partial emphasis
        while currentIndex >= 0 {
            let child = parentNode.children[currentIndex]
            
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // Calculate number of consecutive partials backward at this position
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
                
                // Check if a match is possible
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
    
    /// Replace matched partial emphasis with final emphasis node
    private func replacePartialWithEmphasis(in parentNode: CodeNode, matchResult: EmphasisMatchResult) {
        // Collect content nodes
        var contentNodes: [CodeNode] = []
        for i in matchResult.contentStart..<matchResult.contentEnd {
            contentNodes.append(parentNode.children[i])
        }
        
        // Create emphasis node
        let emphasisNode = createEmphasisNode(
            matchCount: matchResult.matchCount,
            contentNodes: contentNodes,
            range: parentNode.children[matchResult.startIndex].range ?? contentNodes.first?.range ?? "".startIndex..<"".endIndex
        )
        
        // Remove end partial nodes (from back to front)
        let endRemoveStart = matchResult.endIndex
        let endRemoveEnd = matchResult.endIndex + matchResult.matchCount
        for i in (endRemoveStart..<endRemoveEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // Remove content nodes (from back to front)
        for i in (matchResult.contentStart..<matchResult.contentEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // Remove matched start partial nodes (from back to front)
        let startRemoveEnd = matchResult.startIndex + matchResult.matchCount
        for i in (matchResult.startIndex..<startRemoveEnd).reversed() {
            if i < parentNode.children.count {
                parentNode.children[i].removeFromParent()
            }
        }
        
        // Insert emphasis node at original position
        let insertIndex = matchResult.startIndex
        if insertIndex <= parentNode.children.count {
            parentNode.insertChild(emphasisNode, at: insertIndex)
        } else {
            parentNode.addChild(emphasisNode)
        }
        
        // Handle remaining partial nodes
        let remainingStart = matchResult.startCount - matchResult.matchCount
        let remainingEnd = matchResult.endCount - matchResult.matchCount
        
        // Insert remaining start partials before emphasis
        for i in 0..<remainingStart {
            let partialNode = CodeNode(
                type: MarkdownElement.partialEmphasis,
                value: matchResult.marker,
                range: parentNode.children.first?.range ?? "".startIndex..<"".endIndex
            )
            parentNode.insertChild(partialNode, at: insertIndex + i)
        }
        
        // Insert remaining end partials after emphasis
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
    
    /// Create emphasis node (content represented only through children)
    private func createEmphasisNode(matchCount: Int, contentNodes: [CodeNode], range: Range<String.Index>) -> CodeNode {
        if matchCount >= 3 {
            // ***text*** -> strongEmphasis with nested emphasis
            let strongNode = CodeNode(type: MarkdownElement.strongEmphasis, value: "", range: range)
            let emphasisNode = CodeNode(type: MarkdownElement.emphasis, value: "", range: range)
            
            // Add content nodes to emphasis node
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                emphasisNode.addChild(contentNode)
            }
            
            strongNode.addChild(emphasisNode)
            return strongNode
            
        } else if matchCount >= 2 {
            // **text** -> strongEmphasis
            let strongNode = CodeNode(type: MarkdownElement.strongEmphasis, value: "", range: range)
            
            // Add content nodes to strong node
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                strongNode.addChild(contentNode)
            }
            
            return strongNode
            
        } else {
            // *text* -> emphasis
            let emphasisNode = CodeNode(type: MarkdownElement.emphasis, value: "", range: range)
            
            // Add content nodes to emphasis node
            for contentNode in contentNodes {
                contentNode.removeFromParent()
                emphasisNode.addChild(contentNode)
            }
            
            return emphasisNode
        }
    }
    
    /// Post-process partial emphasis, called after parsing is complete
    func postProcessPartialEmphasis(_ node: CodeNode) {
        // Analyze all partial emphasis and try to match
        resolveAllPartialEmphasis(node)
    }
    
    /// Resolve all partial emphasis in the node
    private func resolveAllPartialEmphasis(_ node: CodeNode) {
        var changed = true
        
        // Repeat processing until no changes
        while changed {
            changed = false
            
            // Find matchable emphasis pairs
            for marker in ["*", "_"] {
                if findAndResolveEmphasisPair(node, marker: marker) {
                    changed = true
                    break
                }
            }
        }
    }
    
    /// Find and resolve an emphasis marker pair
    private func findAndResolveEmphasisPair(_ node: CodeNode, marker: String) -> Bool {
        var openPositions: [Int] = []
        var closePosition: Int? = nil
        
        // Scan from front to back, find opening markers, find first matchable one from back to front
        for (i, child) in node.children.enumerated() {
            if let element = child.type as? MarkdownElement,
               element == .partialEmphasis,
               child.value == marker {
                
                // Check if there's non-partial content after this position
                let hasContentAfter = i + 1 < node.children.count && 
                                    !(node.children[i + 1].type is MarkdownElement && 
                                      (node.children[i + 1].type as! MarkdownElement) == .partialEmphasis)
                
                if hasContentAfter && openPositions.isEmpty {
                    // This is a potential opening marker
                    openPositions.append(i)
                } else if !openPositions.isEmpty {
                    // This is a potential closing marker
                    closePosition = i
                    break
                }
            }
        }
        
        // If found matching pair, create emphasis
        if let closePos = closePosition, !openPositions.isEmpty {
            let openPos = openPositions.last!
            
            // Collect content nodes
            var contentNodes: [CodeNode] = []
            for i in (openPos + 1)..<closePos {
                contentNodes.append(node.children[i])
            }
            
            // Create emphasis node
            let emphasisNode = CodeNode(
                type: MarkdownElement.emphasis,
                value: "",
                range: node.children[openPos].range ?? "".startIndex..<"".endIndex
            )
            
            // Remove original nodes and reorganize
            // Remove from back to front to avoid index confusion
            for i in (openPos...closePos).reversed() {
                node.children[i].removeFromParent()
            }
            
            // Add content to emphasis node
            for contentNode in contentNodes {
                emphasisNode.addChild(contentNode)
            }
            
            // Insert emphasis node at original position
            node.insertChild(emphasisNode, at: openPos)
            
            return true
        }
        
        return false
    }
    
    /// Find optimal emphasis match - prioritize larger matches
    private func findBestEmphasisMatch(_ tokens: [FlatToken], startIndex: Int, marker: String) -> EmphasisMatch? {
        var i = startIndex
        var startCount = 0
        
        // Calculate number of starting markers
        while i < tokens.count && tokens[i].type == .partial && tokens[i].content == marker {
            startCount += 1
            i += 1
        }
        
        if startCount == 0 {
            return nil
        }
        
        // Collect all possible matches
        var possibleMatches: [EmphasisMatch] = []
        let contentStart = i
        var searchIndex = contentStart
        
        while searchIndex < tokens.count {
            if tokens[searchIndex].type == .partial && tokens[searchIndex].content == marker {
                // Calculate number of ending markers
                var endCount = 0
                var tempIndex = searchIndex
                
                while tempIndex < tokens.count && tokens[tempIndex].type == .partial && tokens[tempIndex].content == marker {
                    endCount += 1
                    tempIndex += 1
                }
                
                // Calculate possible matches
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
        
        // Choose best match: prioritize largest matchCount
        let bestMatch = possibleMatches.max { match1, match2 in
            if match1.count != match2.count {
                return match1.count < match2.count  // Prioritize larger count
            }
            // If count is same, choose farther distance (containing more content)
            return match1.endIndex < match2.endIndex
        }
        
        
        return bestMatch
    }
    
    /// Create emphasis node from tokens
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
                // Recursively handle nested emphasis
                if let nestedMatch = findBestEmphasisMatch(tokens, startIndex: i, marker: marker) {
                    let contentTokens = Array(tokens[(i + nestedMatch.count)..<nestedMatch.endIndex])
                    let nestedNode = createEmphasisFromTokens(contentTokens, matchCount: nestedMatch.count, marker: marker)
                    emphasisNode.addChild(nestedNode)
                    i = nestedMatch.endIndex + nestedMatch.count
                } else {
                    // Keep as partial
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

/// Structure representing emphasis match result
private struct EmphasisMatchResult {
    let startIndex: Int      // Position of start partial nodes
    let startCount: Int      // Number of start partial nodes
    let contentStart: Int    // Content start position
    let contentEnd: Int      // Content end position
    let endIndex: Int        // Position of end partial nodes
    let endCount: Int        // Number of end partial nodes
    let matchCount: Int      // Actual matched marker count
    let marker: String       // Marker character
}

/// Consumer for handling inline code
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
        
        // Find closing backtick
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
            // No closing marker found, treat as regular text
            let textNode = CodeNode(type: MarkdownElement.text, value: "`" + codeText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// Consumer for handling footnote references
public class MarkdownFootnoteReferenceConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if it's a footnote reference start: [^identifier]
        if mdToken.kind == .leftBracket {
            // Check if next token is ^
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
            
            // If no right bracket found, not a valid footnote reference
            guard tokenIndex <= context.tokens.count && !identifier.isEmpty else {
                return false
            }
            
            // Remove processed tokens
            for _ in 0..<tokenIndex {
                context.tokens.removeFirst()
            }
            
            let footnoteRef = CodeNode(type: MarkdownElement.footnoteReference, value: identifier, range: mdToken.range)
            context.currentNode.addChild(footnoteRef)
            return true
        }
        
        return false
    }
}

/// Consumer for handling citation references
public class MarkdownCitationReferenceConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if it's a citation reference start: [@identifier]
        if mdToken.kind == .leftBracket {
            // Check if next token is @
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
            
            // If no right bracket found, not a valid citation reference
            guard tokenIndex <= context.tokens.count && !identifier.isEmpty else {
                return false
            }
            
            // Remove processed tokens
            for _ in 0..<tokenIndex {
                context.tokens.removeFirst()
            }
            
            let citationRef = CodeNode(type: MarkdownElement.citationReference, value: identifier, range: mdToken.range)
            context.currentNode.addChild(citationRef)
            return true
        }
        
        return false
    }
}

/// Consumer for handling footnote and citation backtrack reorganization
/// This Consumer checks and reorganizes possible footnote and citation structures after parsing is complete
public class MarkdownFootnoteAndCitationReorganizer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        // This consumer mainly performs backtrack reorganization at the end of parsing
        // Check if there are footnote or citation structures that need reorganization
        
        // If current token is EOF, perform backtrack reorganization
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .eof {
            reorganizeFootnotesAndCitations(context: &context)
            return false // Don't consume EOF token
        }
        
        return false
    }
    
    /// Backtrack reorganization of footnote and citation structures
    private func reorganizeFootnotesAndCitations(context: inout CodeContext) {
        // Traverse the entire AST to find possible footnote and citation patterns
        traverseAndReorganize(context.currentNode)
    }
    
    /// Traverse nodes and reorganize footnotes and citations
    private func traverseAndReorganize(_ node: CodeNode) {
        // Handle child nodes first
        for child in node.children {
            traverseAndReorganize(child)
        }
        
        // Then process the current node
        reorganizeNodeChildren(node)
    }
    
    /// Reorganize node children, looking for footnote and citation patterns
    private func reorganizeNodeChildren(_ node: CodeNode) {
        var i = 0
        while i < node.children.count {
            let child = node.children[i]
            
            // Check if it's a potential footnote or citation pattern
            if let element = child.type as? MarkdownElement {
                if element == .partialLink {
                    // Check if it's a footnote reference pattern [^identifier]
                    if child.value.hasPrefix("^") {
                        let identifier = String(child.value.dropFirst()) // Remove ^
                        let footnoteRef = CodeNode(type: MarkdownElement.footnoteReference, value: identifier, range: child.range)
                        node.replaceChild(at: i, with: footnoteRef)
                        
                    }
                    // Check if it's a citation reference pattern [@identifier]
                    else if child.value.hasPrefix("@") {
                        let identifier = String(child.value.dropFirst()) // Remove @
                        let citationRef = CodeNode(type: MarkdownElement.citationReference, value: identifier, range: child.range)
                        node.replaceChild(at: i, with: citationRef)
                        
                    }
                }
            }
            
            i += 1
        }
    }
}

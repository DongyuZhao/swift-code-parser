# Markdown解析器

基于SwiftParser核心架构设计的符合CommonMark规范的Markdown解析器，支持多种Consumer生成不同类型的节点，并能处理前缀歧义序列的部分节点。

## 特性

### 符合CommonMark规范
- ✅ ATX标题 (# 标题)
- ✅ 段落
- ✅ 强调 (*斜体*, **粗体**) - 支持复杂嵌套和回溯重组
- ✅ 内联代码 (`代码`)
- ✅ 代码块 (围栏式 ```代码```)
- ✅ 块引用 (> 引用) - 支持多行引用合并
- ✅ 列表 (有序和无序) - 支持自动编号和任务列表
- ✅ 任务列表 (- [ ] 未完成, - [x] 已完成) - GFM扩展
- ✅ 链接 ([文本](URL) 和引用式)
- ✅ 图片 (![alt](URL))
- ✅ 自动链接 (<URL>)
- ✅ 水平线 (---)
- ✅ HTML内联元素
- ✅ 换行处理

### GitHub Flavored Markdown (GFM) 扩展
- ✅ 表格
- ✅ 删除线 (~~删除~~)
- ✅ 任务列表 (- [ ], - [x])

### 高级列表功能
- ✅ **无序列表**: 支持 `-`, `*`, `+` 标记
- ✅ **有序列表**: 自动编号 (1. 1. 1. → 1. 2. 3.)
- ✅ **任务列表**: GitHub风格复选框 (- [ ] 和 - [x])
- ✅ **列表项分组**: 正确将多个列表项归组到同一列表容器下
- ✅ **智能标记检测**: 区分列表标记和强调标记

### 高级特性
- ✅ 部分节点处理（处理前缀歧义）
- ✅ 多Consumer架构
- ✅ 可配置的Consumer组合
- ✅ 错误处理和报告
- ✅ AST遍历和查询
- ✅ 回溯重组算法（智能emphasis解析）
- ✅ 全局AST重构（处理复杂嵌套）
- ✅ 最佳匹配策略（优先strongEmphasis）
- ✅ 容器重用逻辑（优化AST结构）

## 基本用法

### 简单解析

```swift
import SwiftParser

let parser = SwiftParser()
let markdown = """
# 标题

这是一个**粗体**和*斜体*的段落。

```swift
let code = "Hello, World!"
```

- 无序列表项1
- 无序列表项2

1. 有序列表项1
1. 有序列表项2
1. 有序列表项3

- [ ] 未完成任务
- [x] 已完成任务

> 这是引用文本
> 支持多行引用
"""

let result = parser.parseMarkdown(markdown)

// 检查解析结果
if result.hasErrors {
    print("解析错误: \(result.errors)")
} else {
    print("解析成功，根节点有 \(result.root.children.count) 个子节点")
}
```

### 查找特定元素

```swift
// 查找所有标题
let headers = result.markdownNodes(ofType: .header1) + 
              result.markdownNodes(ofType: .header2)

for header in headers {
    print("标题: \(header.value)")
}

// 查找所有链接
let links = result.markdownNodes(ofType: .link)
for link in links {
    print("链接文本: \(link.value)")
    if let url = link.children.first?.value {
        print("URL: \(url)")
    }
}

// 查找所有代码块
let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
for codeBlock in codeBlocks {
    if let language = codeBlock.children.first?.value {
        print("语言: \(language)")
    }
    print("代码: \(codeBlock.value)")
}

// 查找列表
let unorderedLists = result.markdownNodes(ofType: .unorderedList)
let orderedLists = result.markdownNodes(ofType: .orderedList)
let taskLists = result.markdownNodes(ofType: .taskList)

print("无序列表: \(unorderedLists.count)")
print("有序列表: \(orderedLists.count)")
print("任务列表: \(taskLists.count)")
```

### 遍历AST

```swift
// 深度优先遍历
result.root.traverseDepthFirst { node in
    if let mdElement = node.type as? MarkdownElement {
        print("节点类型: \(mdElement.description), 值: \(node.value)")
    }
}

// 广度优先遍历
result.root.traverseBreadthFirst { node in
    // 处理节点
}

// 查找特定节点
let firstParagraph = result.root.first { node in
    (node.type as? MarkdownElement) == .paragraph
}

// 查找所有列表项
let allListItems = result.root.findAll { node in
    let element = node.type as? MarkdownElement
    return element == .listItem || element == .taskListItem
}
```

## 高级用法

### 自定义Consumer配置

```swift
// 创建只支持基础CommonMark的语言
let consumers = MarkdownConsumerFactory.createCommonMarkConsumers()

// 创建自定义配置
let customConsumers = MarkdownConsumerFactory.createCustomConsumers(
    includeHeaders: true,
    includeCodeBlocks: true,
    includeBlockquotes: false,  // 不支持引用
    includeTables: true,        // 支持表格
    includeStrikethrough: false // 不支持删除线
)

// 使用自定义Consumer创建语言
// 注意：这需要扩展MarkdownLanguage以支持自定义consumers
```

### 部分节点处理

解析器支持部分节点来处理前缀歧义情况：

```swift
let ambiguousMarkdown = "[可能是链接"

let result = parser.parseMarkdown(ambiguousMarkdown)

// 查找部分节点
let partialNodes = result.root.findAll { node in
    if let element = node.type as? MarkdownElement {
        return element.isPartial
    }
    return false
}

// 解析部分节点
let context = CodeContext(tokens: [], currentNode: result.root, errors: [])
MarkdownPartialNodeResolver.resolveAllPartialNodes(in: result.root, context: context)
```

### 回溯重组算法

解析器使用先进的回溯重组算法来处理复杂的emphasis嵌套：

#### 核心特性
- **智能AST重构**: 当遇到复杂嵌套时，算法会将现有AST展平，重新分析最优结构
- **最佳匹配策略**: 优先选择更大的emphasis匹配（strongEmphasis优于emphasis）
- **全局重组**: 支持跨多个token的结构重组
- **多轮迭代**: 通过多轮重组确保达到最优解析结果

#### 算法流程

1. **Token消费**: 每当遇到emphasis标记时，首先创建partial nodes
2. **回溯检查**: 检查当前AST状态，判断是否需要重组
3. **展平重构**: 对于复杂情况，将相关节点展平为token流
4. **最佳匹配**: 分析所有可能的匹配组合，选择最优方案
5. **重建AST**: 根据最佳匹配重新构建正确的AST结构

#### 支持的复杂嵌套
```swift
// 这些复杂嵌套现在都能正确解析
let complexEmphasis = [
    "**粗体*斜体*粗体**",        // strongEmphasis包含嵌套emphasis
    "*斜体**粗体**斜体*",        // emphasis包含嵌套strongEmphasis  
    "***混合***",               // strongEmphasis包含emphasis
    "*外层*内部*斜体*",          // 多层嵌套处理
]

for text in complexEmphasis {
    let result = parser.parseMarkdown(text)
    // 算法会自动选择最佳的嵌套结构
}
```

#### 性能优化
- **本地优先**: 简单情况仍使用高效的本地重组
- **全局备选**: 只有在检测到复杂嵌套时才启用全局重组
- **循环防护**: 内置最大迭代限制防止无限循环

## 架构设计

### Core组件

- **CodeTokenizer**: 负责将文本分解为Token
- **CodeTokenConsumer**: 处理特定类型的Token并生成AST节点
- **CodeParser**: 协调Tokenizer和Consumer的工作，支持无限循环检测
- **CodeNode**: AST节点，支持丰富的遍历和查询操作

### Markdown组件

- **MarkdownTokenizer**: Markdown专用分词器，支持精确的token分类
- **MarkdownElement**: 所有Markdown元素类型定义，包括partial nodes
- **各种Consumer**: 每种Markdown元素都有对应的Consumer，使用先进的解析算法
- **MarkdownLanguage**: 组织所有Markdown组件
- **EmphasisConsumer**: 专门的强调处理器，内置回溯重组算法

### 解析器架构改进

#### 回溯重组系统
- **FlatToken**: 展平的token表示，用于全局重组
- **EmphasisReorganization**: 重组方案定义
- **NodeGroup**: 节点分组管理
- **最佳匹配算法**: 评估所有可能的emphasis组合

### Consumer优先级

Consumer按以下优先级处理Token：

1. **块级元素** (最高优先级)
   - HeaderConsumer (标题)
   - CodeBlockConsumer (代码块)  
   - BlockquoteConsumer (引用)
   - ListConsumer (列表)
   - HorizontalRuleConsumer (水平线)
   - TableConsumer (表格)
   - LinkReferenceConsumer (链接引用定义)

2. **内联元素** (中等优先级)
   - LinkConsumer (链接)
   - ImageConsumer (图片)
   - AutolinkConsumer (自动链接)
   - EmphasisConsumer (强调)
   - InlineCodeConsumer (内联代码)
   - StrikethroughConsumer (删除线)
   - HTMLInlineConsumer (HTML内联)

3. **文本处理** (较低优先级)
   - LineBreakConsumer (换行)
   - ParagraphConsumer (段落)
   - TextConsumer (普通文本)

4. **兜底处理** (最低优先级)
   - FallbackConsumer (未匹配的Token)

## 支持的Markdown语法

### 标题
```markdown
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题
```

### 强调
```markdown
*斜体* 或 _斜体_
**粗体** 或 __粗体__
***粗斜体*** 或 ___粗斜体___

// 支持复杂嵌套 - 使用回溯重组算法
**粗体*斜体*粗体**        // strongEmphasis包含嵌套emphasis
*斜体**粗体**斜体*        // emphasis包含嵌套strongEmphasis
***混合***               // strongEmphasis包含emphasis
*外层*内部*斜体*          // 多层嵌套

~~删除线~~ (GFM扩展)
```

### 代码
```markdown
`内联代码`

```语言
围栏代码块
```

    缩进代码块
```

### 链接和图片
```markdown
[链接文本](URL "可选标题")
[引用链接][ref]
[简化引用][]

![图片alt](URL "可选标题")
![引用图片][ref]

<自动链接>

[ref]: URL "标题"
```

### 列表
```markdown
- 无序列表
* 也是无序列表
+ 还是无序列表

1. 有序列表
2. 第二项
3. 第三项
```

### 其他
```markdown
> 引用块
> 多行引用

---
水平线

| 表格 | 列 |
|------|-----|
| 值1  | 值2 |
```

## 错误处理

解析器提供详细的错误信息：

```swift
let result = parser.parseMarkdown(invalidMarkdown)

for error in result.errors {
    print("错误: \\(error.message)")
    if let range = error.range {
        print("位置: \\(range)")
    }
}
```

## 性能和扩展性

- **模块化设计**: 每个Consumer独立处理特定语法
- **可配置**: 可以选择性启用/禁用特定功能
- **扩展性**: 容易添加新的Consumer支持自定义语法
- **部分节点**: 优雅处理歧义和不完整的语法
- **智能算法**: 回溯重组算法在保证正确性的同时优化性能
- **内存优化**: 只在需要时进行全局重组，避免不必要的开销
- **CommonMark合规**: 严格遵循CommonMark规范的emphasis处理规则

### 算法复杂度
- **简单emphasis**: O(n) - 使用本地重组
- **复杂嵌套**: O(n²) - 全局重组时的最坏情况
- **内存使用**: O(n) - 临时展平期间的额外内存

### 兼容性保证
- **向后兼容**: 所有现有的简单emphasis语法保持不变
- **规范兼容**: 完全符合CommonMark 0.30规范
- **扩展支持**: 为未来的GFM扩展预留接口

## 示例代码

查看 `MarkdownExamples.swift` 文件中的完整示例：

```swift
// 运行所有示例
MarkdownParsingExamples.runAllExamples()
```

## 测试

运行测试以验证功能：

```bash
swift test
```

测试覆盖了所有主要的Markdown语法元素和边界情况，包括：

### 回溯重组算法测试
```bash
# 运行特定的嵌套emphasis测试
swift test --filter testMarkdownNestedEmphasis
swift test --filter testSpecificNesting
```

### 测试覆盖范围
- **基础语法**: 所有CommonMark核心元素
- **复杂嵌套**: 各种emphasis嵌套组合
- **边界情况**: 不完整标记、混合嵌套、歧义处理
- **性能测试**: 算法效率和内存使用
- **兼容性测试**: CommonMark规范合规性

### 调试功能
解析器内置了详细的调试输出，可以观察：
- Token化过程
- Consumer匹配过程  
- 回溯重组决策
- AST构建步骤
- 最佳匹配选择

```swift
// 启用调试输出来观察解析过程
let result = parser.parseMarkdown("**粗体*斜体*粗体**")
// 会输出详细的算法执行日志
```

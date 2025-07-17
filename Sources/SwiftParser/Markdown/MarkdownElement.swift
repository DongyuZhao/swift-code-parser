import Foundation

/// Markdown element definitions following the CommonMark specification
public enum MarkdownElement: CodeElement, CaseIterable {
    // Block-level elements
    case document
    case paragraph
    case header1, header2, header3, header4, header5, header6
    case codeBlock
    case fencedCodeBlock
    case blockquote
    case unorderedList
    case orderedList
    case listItem
    case taskList          // Task list (GFM extension)
    case taskListItem      // Task list item with checkbox
    case nestedList        // Container for nested lists
    case horizontalRule
    case htmlBlock
    case table
    case tableRow
    case tableCell
    case linkReferenceDefinition
    
    // Inline elements
    case text
    case emphasis
    case strongEmphasis
    case inlineCode
    case link
    case image
    case autolink
    case htmlInline
    case lineBreak
    case softBreak
    case strikethrough
    
    // Partial nodes for prefix ambiguity
    case partialHeader
    case partialCodeBlock
    case partialEmphasis
    case partialStrongEmphasis
    case partialLink
    case partialImage
    case partialFencedCodeBlock
    case partialList
    case partialBlockquote
    case partialTable
    
    public var isBlockLevel: Bool {
        switch self {
        case .document, .paragraph, .header1, .header2, .header3, .header4, .header5, .header6,
             .codeBlock, .fencedCodeBlock, .blockquote, .unorderedList, .orderedList, .listItem,
             .taskList, .taskListItem, .nestedList,
             .horizontalRule, .htmlBlock, .table, .tableRow, .tableCell, .linkReferenceDefinition:
            return true
        default:
            return false
        }
    }
    
    public var isInlineLevel: Bool {
        switch self {
        case .text, .emphasis, .strongEmphasis, .inlineCode, .link, .image, .autolink,
             .htmlInline, .lineBreak, .softBreak, .strikethrough:
            return true
        default:
            return false
        }
    }
    
    public var isPartial: Bool {
        switch self {
        case .partialHeader, .partialCodeBlock, .partialEmphasis, .partialStrongEmphasis,
             .partialLink, .partialImage, .partialFencedCodeBlock, .partialList,
             .partialBlockquote, .partialTable:
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .document: return "document"
        case .paragraph: return "paragraph"
        case .header1: return "header1"
        case .header2: return "header2"
        case .header3: return "header3"
        case .header4: return "header4"
        case .header5: return "header5"
        case .header6: return "header6"
        case .codeBlock: return "codeBlock"
        case .fencedCodeBlock: return "fencedCodeBlock"
        case .blockquote: return "blockquote"
        case .unorderedList: return "unorderedList"
        case .orderedList: return "orderedList"
        case .listItem: return "listItem"
        case .taskList: return "taskList"
        case .taskListItem: return "taskListItem"
        case .nestedList: return "nestedList"
        case .horizontalRule: return "horizontalRule"
        case .htmlBlock: return "htmlBlock"
        case .table: return "table"
        case .tableRow: return "tableRow"
        case .tableCell: return "tableCell"
        case .linkReferenceDefinition: return "linkReferenceDefinition"
        case .text: return "text"
        case .emphasis: return "emphasis"
        case .strongEmphasis: return "strongEmphasis"
        case .inlineCode: return "inlineCode"
        case .link: return "link"
        case .image: return "image"
        case .autolink: return "autolink"
        case .htmlInline: return "htmlInline"
        case .lineBreak: return "lineBreak"
        case .softBreak: return "softBreak"
        case .strikethrough: return "strikethrough"
        case .partialHeader: return "partialHeader"
        case .partialCodeBlock: return "partialCodeBlock"
        case .partialEmphasis: return "partialEmphasis"
        case .partialStrongEmphasis: return "partialStrongEmphasis"
        case .partialLink: return "partialLink"
        case .partialImage: return "partialImage"
        case .partialFencedCodeBlock: return "partialFencedCodeBlock"
        case .partialList: return "partialList"
        case .partialBlockquote: return "partialBlockquote"
        case .partialTable: return "partialTable"
        }
    }
}

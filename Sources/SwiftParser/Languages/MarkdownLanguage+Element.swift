import Foundation

extension MarkdownLanguage {
    public enum Element: String, CodeElement {
        case root
        case paragraph
        case heading
        case text
        case listItem
        case orderedListItem
        case unorderedList
        case orderedList
        case emphasis
        case strong
        case codeBlock
        case inlineCode
        case link
        case blockQuote
        case thematicBreak
        case image
        case html
        case entity
        case strikethrough
        case table
        case tableHeader
        case tableRow
        case tableCell
        case autoLink
        case linkReferenceDefinition
        case footnoteDefinition
        case footnoteReference
        case inlineTexFormula
        case blockTexFormula
    }

}

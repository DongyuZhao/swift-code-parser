import Foundation

/// Markdown parsing examples and usage
public class MarkdownParsingExamples {
    
    /// Basic Markdown parsing example
    public static func basicExample() {
        let markdown = """
        # Title
        
        This is a paragraph with **bold** text and *italic* text.
        
        ## Code Example
        
        ```swift
        let code = "Hello, World!"
        print(code)
        ```
        
        - List item 1
        - List item 2
        - List item 3
        
        > This is a blockquote
        > containing multiple lines
        
        [Link text](https://example.com "Title")
        
        ![Image alt](image.jpg "Image title")
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        print("Parse result:")
        print("- Has errors: \(result.hasErrors)")
        print("- Error count: \(result.errors.count)")
        print("- Root node type: \(result.root.type)")
        print("- Child node count: \(result.root.children.count)")
        
        // Traverse all nodes
        result.root.traverseDepthFirst { node in
            if let mdElement = node.type as? MarkdownElement {
                print("Node: \(mdElement.description) - Value: '\(node.value)'")
            }
        }
    }
    
    /// Example of finding specific node types
    public static func findSpecificNodesExample() {
        let markdown = """
        # Main Title
        
        ## Subtitle
        
        ### Small Title
        
        This is paragraph text.
        
        ```python
        print("Hello")
        ```
        
        - Item 1
        - Item 2
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // Find all headers
        let headers = result.markdownNodes(ofType: .header1) + 
                     result.markdownNodes(ofType: .header2) + 
                     result.markdownNodes(ofType: .header3)
        
        print("Found \(headers.count) headers:")
        for header in headers {
            print("- \(header.value)")
        }
        
        // Find all code blocks
        let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
        print("Found \(codeBlocks.count) code blocks:")
        for codeBlock in codeBlocks {
            print("- Language: \(codeBlock.children.first?.value ?? "unspecified")")
            print("- Content: \(codeBlock.value)")
        }
        
        // Find all lists
        let lists = result.markdownNodes(ofType: .unorderedList)
        print("Found \(lists.count) unordered lists:")
        for list in lists {
            print("- Contains \(list.children.count) items")
        }
    }
    
    /// Table parsing example (GFM extension)
    public static func tableExample() {
        let markdown = """
        | Name | Age | City |
        |------|-----|------|
        | John | 25  | Beijing |
        | Jane | 30  | Shanghai |
        | Bob  | 35  | Guangzhou |
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        let tables = result.markdownNodes(ofType: .table)
        print("Found \(tables.count) tables:")
        
        for table in tables {
            print("Table contains \(table.children.count) rows:")
            for (rowIndex, row) in table.children.enumerated() {
                if let tableRow = row.type as? MarkdownElement, tableRow == .tableRow {
                    print("  Row \(rowIndex + 1): \(row.children.count) columns")
                    for (colIndex, cell) in row.children.enumerated() {
                        print("    Column \(colIndex + 1): '\(cell.value)'")
                    }
                }
            }
        }
    }
    
    /// Link parsing example
    public static func linkExample() {
        let markdown = """
        Here are several different types of links:
        
        1. Inline link: [Google](https://google.com "Search Engine")
        2. Reference link: [GitHub][github]
        3. Simplified reference: [GitHub][]
        4. Autolink: <https://example.com>
        5. Image: ![Logo](logo.png "Company Logo")
        
        [github]: https://github.com "Code Hosting Platform"
        [GitHub]: https://github.com
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // Find all links
        let links = result.markdownNodes(ofType: .link)
        print("Found \(links.count) links:")
        for link in links {
            print("- Text: '\(link.value)'")
            if let urlNode = link.children.first {
                print("  URL: '\(urlNode.value)'")
            }
            if link.children.count > 1 {
                print("  Title: '\(link.children[1].value)'")
            }
        }
        
        // Find all images
        let images = result.markdownNodes(ofType: .image)
        print("Found \(images.count) images:")
        for image in images {
            print("- Alt text: '\(image.value)'")
            if let urlNode = image.children.first {
                print("  URL: '\(urlNode.value)'")
            }
        }
        
        // Find all autolinks
        let autolinks = result.markdownNodes(ofType: .autolink)
        print("Found \(autolinks.count) autolinks:")
        for autolink in autolinks {
            print("- URL: '\(autolink.value)'")
        }
        
        // Find link reference definitions
        let linkRefs = result.markdownNodes(ofType: .linkReferenceDefinition)
        print("Found \(linkRefs.count) link reference definitions:")
        for linkRef in linkRefs {
            print("- Label: '\(linkRef.value)'")
            if let urlNode = linkRef.children.first {
                print("  URL: '\(urlNode.value)'")
            }
        }
    }
    
    /// Emphasis and code example
    public static func emphasisAndCodeExample() {
        let markdown = """
        Here are various emphasis and code examples:
        
        *Italic text* and _another italic_
        
        **Bold text** and __another bold__
        
        ~~Strikethrough text~~
        
        `Inline code` and some `other code`
        
        ```swift
        // This is a code block
        func hello() {
            print("Hello, World!")
        }
        ```
        
            // This is an indented code block
            let x = 42
            print(x)
        """
        
        let parser = SwiftParser()
        let result = parser.parseMarkdown(markdown)
        
        // Find emphasis
        let emphasis = result.markdownNodes(ofType: .emphasis)
        print("Found \(emphasis.count) italic texts:")
        for em in emphasis {
            print("- '\(em.value)'")
        }
        
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        print("Found \(strongEmphasis.count) bold texts:")
        for strong in strongEmphasis {
            print("- '\(strong.value)'")
        }
        
        let strikethrough = result.markdownNodes(ofType: .strikethrough)
        print("Found \(strikethrough.count) strikethrough texts:")
        for strike in strikethrough {
            print("- '\(strike.value)'")
        }
        
        // Find code
        let inlineCode = result.markdownNodes(ofType: .inlineCode)
        print("Found \(inlineCode.count) inline codes:")
        for code in inlineCode {
            print("- '\(code.value)'")
        }
        
        let fencedCode = result.markdownNodes(ofType: .fencedCodeBlock)
        print("Found \(fencedCode.count) fenced code blocks:")
        for code in fencedCode {
            if let lang = code.children.first {
                print("- Language: '\(lang.value)'")
            }
            print("- Content: '\(code.value)'")
        }
        
        let indentedCode = result.markdownNodes(ofType: .codeBlock)
        print("Found \(indentedCode.count) indented code blocks:")
        for code in indentedCode {
            print("- Content: '\(code.value)'")
        }
    }
    
    /// Run all examples
    public static func runAllExamples() {
        print("=== Basic Parsing Example ===")
        basicExample()
        
        print("\n=== Find Specific Nodes Example ===")
        findSpecificNodesExample()
        
        print("\n=== Table Parsing Example ===")
        tableExample()
        
        print("\n=== Link Parsing Example ===")
        linkExample()
        
        print("\n=== Emphasis and Code Example ===")
        emphasisAndCodeExample()
    }
}

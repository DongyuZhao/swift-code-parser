import XCTest
@testable import SwiftParser

final class SwiftParserTests: XCTestCase {
    
    func testParserInitialization() {
        let parser = SwiftParser()
        XCTAssertNotNil(parser)
    }
    
    func testBasicParsing() {
        let parser = SwiftParser()
        let sourceCode = "let x = 42"
        
        let result = parser.parse(sourceCode)
        
        XCTAssertEqual(result.content, sourceCode)
    }
    
    func testEmptySourceParsing() {
        let parser = SwiftParser()
        let sourceCode = ""
        
        let result = parser.parse(sourceCode)
        
        XCTAssertEqual(result.content, sourceCode)
    }
    
    func testComplexSourceParsing() {
        let parser = SwiftParser()
        let sourceCode = """
        import Foundation
        
        struct Example {
            let name: String
            
            func greet() {
                print("Hello, \\(name)!")
            }
        }
        """
        
        let result = parser.parse(sourceCode)
        
        XCTAssertEqual(result.content, sourceCode)
        XCTAssertTrue(result.content.contains("struct Example"))
    }
}

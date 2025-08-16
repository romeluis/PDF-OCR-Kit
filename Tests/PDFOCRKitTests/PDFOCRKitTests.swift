import Testing
import Foundation
@testable import PDFOCRKit

@Test func testPDFOCROptionsInitialization() async throws {
    let defaultOptions = PDFOCROptions()
    #expect(defaultOptions.scale == 2.0)
    #expect(defaultOptions.yTolerance == 10.0)
    
    let customOptions = PDFOCROptions(scale: 1.5, yTolerance: 15.0)
    #expect(customOptions.scale == 1.5)
    #expect(customOptions.yTolerance == 15.0)
}

@Test func testExtractTextWithInvalidURL() async throws {
    let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
    let result = PDFOCRKit.extractText(from: invalidURL)
    #expect(result == "")
}

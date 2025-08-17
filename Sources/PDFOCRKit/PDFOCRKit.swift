//
//  PDFOCRKit.swift
//  PDFOCRKit
//
//  Created by GitHub Copilot on 2025-08-16.
//

import Foundation
import PDFKit
import Vision
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Public API

/// Configuration options for PDF OCR processing
public struct PDFOCROptions {
    /// Rendering scale factor for improved OCR accuracy
    public var scale: CGFloat = 1.5  // Reduced default for better symbol recognition
    /// Y-axis tolerance for grouping text into rows (in pixels)
    public var yTolerance: CGFloat = 10
    /// Whether to enable advanced text correction
    public var enableTextCorrection: Bool = true
    /// Minimum confidence threshold for text recognition (0.0-1.0)
    public var minimumConfidence: CGFloat = 0.5
    
    public init(scale: CGFloat = 1.5, yTolerance: CGFloat = 10, enableTextCorrection: Bool = true, minimumConfidence: CGFloat = 0.5) {
        self.scale = scale
        self.yTolerance = yTolerance
        self.enableTextCorrection = enableTextCorrection
        self.minimumConfidence = minimumConfidence
    }
}

/// Main class for PDF OCR functionality
public class PDFOCRKit {
    
    /// Extract text from a PDF while preserving spatial positioning
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - options: Configuration options for OCR processing
    /// - Returns: Extracted text with preserved spacing
    public static func extractText(from url: URL, options: PDFOCROptions = PDFOCROptions()) -> String {
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess { return "" }

        do {
            let documentData = try Data(contentsOf: url)
            guard let doc = PDFDocument(data: documentData) else { return "" }
            
            var text = ""
            for pageIndex in 0..<doc.pageCount {
                autoreleasepool {
                    if let pageText = ocrPageToText(doc: doc, pageIndex: pageIndex, options: options) {
                        if !text.isEmpty && !pageText.isEmpty {
                            text += "\n\n"
                        }
                        text += pageText
                    }
                }
            }
            
            url.stopAccessingSecurityScopedResource()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            url.stopAccessingSecurityScopedResource()
            return ""
        }
    }
}

// MARK: - Private Implementation

private func ocrPageToText(doc: PDFDocument, pageIndex: Int, options: PDFOCROptions) -> String? {
    guard let cgImage = renderPageImage(doc: doc, pageIndex: pageIndex, scale: options.scale) else {
        return nil
    }
    
    do {
        let words = try recognizeWords(in: cgImage, options: options)
        if words.isEmpty {
            return ""
        }
        
        let rows = groupRows(words, yTolerance: options.yTolerance)
        return rowsToPositionalText(rows)
    } catch {
        return nil
    }
}

private func renderPageImage(doc: PDFDocument, pageIndex: Int, scale: CGFloat) -> CGImage? {
    guard let page = doc.page(at: pageIndex) else { 
        return nil 
    }
    
    let rect = page.bounds(for: .mediaBox)
    let size = CGSize(width: rect.width * scale, height: rect.height * scale)

    #if canImport(UIKit)
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { ctx in
        UIColor.white.set()
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.cgContext.translateBy(x: 0, y: size.height)
        ctx.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: ctx.cgContext)
    }
    return img.cgImage
    #else
    // macOS implementation
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let context = CGContext(data: nil,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else {
        return nil
    }
    
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: scale, y: -scale)
    page.draw(with: .mediaBox, to: context)
    
    return context.makeImage()
    #endif
}

private struct WordBox {
    let text: String
    let rect: CGRect // pixel coords
    var midX: CGFloat { rect.midX }
    var midY: CGFloat { rect.midY }
}

private func recognizeWords(in cgImage: CGImage, options: PDFOCROptions) throws -> [WordBox] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = options.enableTextCorrection
    
    // Try multiple languages
    if #available(iOS 14.0, macOS 11.0, *) {
        req.recognitionLanguages = ["en-US", "en", "en-CA", "es-ES", "fr-FR"]
    }
    
    // Try automatic language detection if available
    if #available(iOS 16.0, macOS 13.0, *) {
        req.automaticallyDetectsLanguage = true
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([req])

    guard let obs = req.results else { 
        return [] 
    }
    
    let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)

    let words = obs.compactMap { o -> WordBox? in
        guard let cand = o.topCandidates(1).first else { return nil }
        
        // Filter by confidence threshold
        if cand.confidence < Float(options.minimumConfidence) {
            return nil
        }
        
        let bb = o.boundingBox // normalized (origin bottom-left)
        let rect = CGRect(x: bb.minX * w,
                          y: (1 - bb.maxY) * h,
                          width: bb.width * w,
                          height: bb.height * h)
        
        // Apply text corrections for common OCR errors
        let correctedText = correctCommonOCRErrors(cand.string)
        
        return WordBox(text: correctedText, rect: rect)
    }
    
    return words
}

// MARK: - Text Correction

private func correctCommonOCRErrors(_ text: String) -> String {
    var corrected = text
    
    // Common grade corrections
    corrected = corrected.replacingOccurrences(of: "Ct", with: "C+")
    corrected = corrected.replacingOccurrences(of: "Bt", with: "B+")
    corrected = corrected.replacingOccurrences(of: "At", with: "A+")
    corrected = corrected.replacingOccurrences(of: "Dt", with: "D+")
    
    // Add space between letters and numbers
    corrected = corrected.replacingOccurrences(of: #"([A-Za-z])(\d)"#, 
                                              with: "$1 $2", 
                                              options: .regularExpression)
    
    // Add space between numbers and letters (for cases like "89Engineering")
    corrected = corrected.replacingOccurrences(of: #"(\d)([A-Za-z])"#, 
                                              with: "$1 $2", 
                                              options: .regularExpression)
    
    return corrected
}

private func groupRows(_ words: [WordBox], yTolerance: CGFloat) -> [[WordBox]] {
    let sorted = words.sorted { $0.midY < $1.midY } // top→bottom after flip
    var rows: [[WordBox]] = []
    for w in sorted {
        if var last = rows.last, let refY = last.last?.midY, abs(w.midY - refY) <= yTolerance {
            last.append(w); rows[rows.count - 1] = last
        } else { rows.append([w]) }
    }
    return rows.map { $0.sorted { $0.rect.minX < $1.rect.minX } }
}

// MARK: - Text positioning

private func rowsToPositionalText(_ rows: [[WordBox]]) -> String {
    var result = ""
    
    for row in rows {
        if row.isEmpty { continue }
        
        if row.count == 1 {
            // Single word in row
            result += row[0].text + "\n"
        } else {
            // Multiple words - preserve spacing based on their positions
            var line = row[0].text
            
            for i in 0..<row.count-1 {
                let currentWord = row[i]
                let nextWord = row[i+1]
                
                // Calculate gap between words based on their pixel positions
                let gap = nextWord.rect.minX - currentWord.rect.maxX
                
                // Smarter spacing logic:
                // - Small gaps (normal word spacing): 1 space
                // - Medium gaps (column separation): 3 spaces
                // - Large gaps (wide column separation): 5 spaces
                let spacerCount: Int
                if gap < 15 {
                    spacerCount = 1  // Normal word spacing
                } else if gap < 40 {
                    spacerCount = 3  // Column separation
                } else {
                    spacerCount = 5  // Wide column separation
                }
                
                line += String(repeating: " ", count: spacerCount) + nextWord.text
            }
            
            result += line + "\n"
        }
    }
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

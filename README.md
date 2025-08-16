# PDFOCRKit

A Swift Package for extracting text from PDF documents while preserving spatial positioning using Apple's Vision framework.

## Features

- **Spatial Text Preservation**: Maintains the original layout and positioning of text from PDFs
- **Cross-Platform**: Works on both iOS (14.0+) and macOS (11.0+)
- **Smart Spacing**: Intelligent spacing detection for tables and multi-column layouts
- **Vision Framework**: Uses Apple's advanced OCR capabilities
- **Simple API**: Easy-to-use public interface

## Installation

### Swift Package Manager

Add PDFOCRKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PDFOCRKit.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import PDFOCRKit

// Extract text from a PDF
let pdfURL = URL(fileURLWithPath: "path/to/your/document.pdf")
let extractedText = PDFOCRKit.extractText(from: pdfURL)
print(extractedText)
```

### Custom Options

```swift
import PDFOCRKit

// Configure OCR options
var options = PDFOCROptions()
options.scale = 1.5              // Rendering scale (default: 2.0)
options.yTolerance = 15          // Row grouping tolerance (default: 10)

let extractedText = PDFOCRKit.extractText(from: pdfURL, options: options)
```

## How It Works

PDFOCRKit uses a sophisticated approach to preserve the spatial layout of text:

1. **PDF Rendering**: Each page is rendered as a high-resolution image
2. **OCR Processing**: Apple's Vision framework extracts text with bounding boxes
3. **Row Grouping**: Text is grouped into logical rows based on Y-coordinate proximity
4. **Smart Spacing**: Gap analysis determines appropriate spacing between columns
   - Small gaps (< 15px): 1 space (normal word spacing)
   - Medium gaps (15-40px): 3 spaces (column separation)
   - Large gaps (> 40px): 5 spaces (wide column separation)

## Requirements

- iOS 14.0+ or macOS 11.0+
- Xcode 12.0+
- Swift 5.3+

## Configuration Options

### PDFOCROptions

- `scale`: Rendering scale factor for improved OCR accuracy (default: 2.0)
- `yTolerance`: Y-axis tolerance for grouping text into rows in pixels (default: 10)

## Example Output

For a PDF with tabular data like:

```
Name          Age    City
John Doe      25     New York
Jane Smith    30     Los Angeles
```

PDFOCRKit will preserve the column alignment:

```
Name          Age    City
John Doe      25     New York
Jane Smith    30     Los Angeles
```

## Testing

Run the test suite:

```bash
swift test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is available under the MIT License. See the LICENSE file for more info.

## Acknowledgments

- Built with Apple's Vision framework
- Uses PDFKit for PDF rendering
- Inspired by the need for better PDF text extraction with layout preservation

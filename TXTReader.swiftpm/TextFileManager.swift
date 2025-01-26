import Foundation

@globalActor actor TextFileActor {
    static let shared = TextFileActor()
}

@TextFileActor
final class TextFileManager: @unchecked Sendable {
    static let shared = TextFileManager()
    private let chunkSize = 50_000 // Characters per chunk
    
    private init() {}
    
    func readFile(at url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        
        // Try Chinese encodings first
        let cfEncodings = [
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue),
            CFStringEncoding(CFStringEncodings.big5.rawValue)
        ]
        
        for cfEncoding in cfEncodings {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            let encoding = String.Encoding(rawValue: nsEncoding)
            if let content = String(data: data, encoding: encoding),
               !content.isEmpty {
                print("Successfully decoded with Chinese encoding")
                return content
            }
        }
        
        // Try common encodings
        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16,
            .windowsCP1252,
            .ascii
        ]
        
        for encoding in encodings {
            if let content = String(data: data, encoding: encoding),
               !content.isEmpty {
                print("Successfully decoded with encoding: \(encoding)")
                return content
            }
        }
        
        throw NSError(domain: "", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not read file with any supported encoding"])
    }
    
    func splitIntoChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        
        return chunks
    }
} 
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FileImporterView: View {
    @State private var isImporting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Button("Select Text File") {
                isImporting = true
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Import File")
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType.plainText, UTType.text],
            onCompletion: { result in
                do {
                    let selectedFile = try result.get()
                    
                    guard selectedFile.startAccessingSecurityScopedResource() else {
                        throw NSError(domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Permission denied to access file"])
                    }
                    
                    defer {
                        selectedFile.stopAccessingSecurityScopedResource()
                    }
                    
                    // Read the file data
                    let data = try Data(contentsOf: selectedFile)
                    let content = try decodeContent(data: data)
                    
                    // Save content to documents directory
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let fileName = selectedFile.lastPathComponent
                    let destinationURL = documentsPath.appendingPathComponent(fileName)
                    try content.write(to: destinationURL, atomically: true, encoding: .utf8)
                    
                    // Parse chapters with a timeout
                    Task {
                        do {
                            let chapters = try await parseChapters(from: content, timeout: 30)
                            try saveChapters(chapters, for: destinationURL)
                        } catch {
                            print("Chapter parsing failed: \(error.localizedDescription)")
                            // Save a default single chapter
                            try saveChapters([Chapter(title: "Full Book", characterOffset: 0)], for: destinationURL)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        dismiss()
                    }
                    
                } catch {
                    print("Error handling file: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        )
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func decodeContent(data: Data) throws -> String {
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
                return content
            }
        }
        
        throw NSError(domain: "", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not read file with any supported encoding"])
    }
    
    private func parseChapters(from text: String, timeout: UInt64) async throws -> [Chapter] {
        return try await withThrowingTaskGroup(of: [Chapter].self) { group in
            // Start the parsing task
            group.addTask {
                let pattern = "^(Chapter|CHAPTER|第)\\s*[0-9一二三四五六七八九十百千]+.*$"
                var chapters: [Chapter] = []
                
                let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)
                
                // Add a limit to prevent infinite processing
                let maxChapters = 1000
                for match in matches.prefix(maxChapters) {
                    if let range = Range(match.range, in: text) {
                        let title = String(text[range])
                        let characterOffset = text.distance(from: text.startIndex, to: range.lowerBound)
                        chapters.append(Chapter(title: title, characterOffset: characterOffset))
                    }
                }
                return chapters
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                throw NSError(domain: "ChapterParsingTimeout", code: 1, userInfo: nil)
            }
            
            // Return first completed result or fallback to default
            do {
                for try await result in group {
                    group.cancelAll() // Cancel other tasks once we have a result
                    return result
                }
            } catch {
                print("Chapter parsing failed or timed out: \(error.localizedDescription)")
            }
            
            // Fallback to single chapter if parsing fails or times out
            return [Chapter(title: "Full Book", characterOffset: 0)]
        }
    }
    
    private func saveChapters(_ chapters: [Chapter], for bookURL: URL) throws {
        let chapterURL = bookURL.deletingPathExtension().appendingPathExtension("chapters.json")
        let data = try JSONEncoder().encode(chapters)
        try data.write(to: chapterURL)
    }
}

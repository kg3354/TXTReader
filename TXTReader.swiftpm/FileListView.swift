import SwiftUI

struct FileListView: View {
    @State private var files: [URL] = []
    @State private var selectedContent: String?
    @State private var showReader = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editMode: EditMode = .inactive
    @State private var selectedFile: URL?
    
    var body: some View {
        ZStack {
            List {
                ForEach(files, id: \.self) { file in
                    Button(action: {
                        if editMode == .inactive {
                            loadContent(from: file)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(file.lastPathComponent)
                                    .foregroundColor(.primary)
                                Text(getFileSize(for: file))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if editMode == .inactive {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete(perform: deleteFiles)
            }
            .navigationTitle("Your Books")
            .navigationDestination(isPresented: $showReader) {
                if let content = selectedContent {
                    BookReaderView(textContent: content, bookURL: selectedFile!)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
            
            // Delete indicator at bottom when in edit mode
            // if editMode == .active {
            //     VStack {
            //         Spacer()
            //         Text("Swipe left to delete books")
            //             .foregroundColor(.secondary)
            //             .padding()
            //             .background(Color.gray.opacity(0.1))
            //             .cornerRadius(10)
            //             .padding(.bottom)
            //     }
            // }
        }
        .onAppear {
            loadFiles()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            files = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "txt" }
        } catch {
            errorMessage = "Error loading files: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        let filesToDelete = offsets.map { files[$0] }
        let fileManager = FileManager.default
        
        for file in filesToDelete {
            do {
                // Delete the main file
                try fileManager.removeItem(at: file)
                
                // Also delete the encoding file if it exists
                let encodingURL = file.deletingPathExtension().appendingPathExtension("encoding")
                try? fileManager.removeItem(at: encodingURL)
            } catch {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        
        // Update the files array
        files.remove(atOffsets: offsets)
    }
    
    private func loadContent(from url: URL) {
        Task {
            do {
                let content = try await TextFileManager.shared.readFile(at: url)
                await MainActor.run {
                    selectedFile = url
                    selectedContent = content
                    showReader = true
                }
            } catch {
                print("Error loading content: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Error loading content: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func getFileSize(for url: URL) -> String {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return ""
    }
}

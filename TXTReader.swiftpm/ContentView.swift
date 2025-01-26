import SwiftUI

struct ContentView: View {
    @StateObject private var settings = UserSettings.shared
    @State private var showFilePicker = false
    @State private var selectedBookURL: URL?
    @State private var showReader = false
    @State private var bookContent = ""
    @State private var books: [URL] = [] // Array to hold the list of books
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationView {
            VStack {
                Text("Your Bookshelf")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(settings.textColor)
                    .padding()

                List {
                    ForEach(books, id: \.self) { bookURL in
                        Button(action: {
                            loadBookContent(from: bookURL)
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text(bookURL.lastPathComponent)
                                    .foregroundColor(settings.textColor)
                            }
                        }
                    }
                    .onDelete(perform: deleteBooks)
                }
                .listStyle(PlainListStyle())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                .environment(\.editMode, $editMode)

                Spacer()

                Button(action: {
                    showFilePicker.toggle()
                }) {
                    Text("Import TXT File")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .sheet(isPresented: $showFilePicker) {
                    FileImporterView()
                        .onDisappear {
                            loadBooks() // Reload the list of books after importing
                        }
                }

                Spacer()

                NavigationLink(
                    destination: BookReaderView(textContent: bookContent, bookURL: selectedBookURL ?? URL(fileURLWithPath: "")),
                    isActive: $showReader
                ) {
                    EmptyView() // Navigation triggered programmatically
                }

                Text("Designed by GuoBuZai 2025")
                    .font(.system(size: 16))
                    .foregroundColor(settings.textColor)
                    .opacity(0.8)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(settings.backgroundColor)
            .onAppear {
                loadBooks()
            }
        }
    }

    private func loadBooks() {
        // Load the list of books from the document directory
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            books = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "txt" }
        } catch {
            print("Error loading books: \(error.localizedDescription)")
        }
    }

    private func loadBookContent(from url: URL) {
        Task {
            do {
                let content = try await TextFileManager.shared.readFile(at: url)
                await MainActor.run {
                    selectedBookURL = url
                    bookContent = content
                    showReader = true
                }
            } catch {
                print("Error loading book content: \(error.localizedDescription)")
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        let booksToDelete = offsets.map { books[$0] }
        let fileManager = FileManager.default
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        for bookURL in booksToDelete {
            do {
                // Delete the main book file
                try fileManager.removeItem(at: bookURL)
                
                // Delete all cached page files for this book
                let cacheFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                for cacheFile in cacheFiles where cacheFile.lastPathComponent.starts(with: bookURL.lastPathComponent) {
                    try? fileManager.removeItem(at: cacheFile)
                }
                
                // Delete the chapters file if it exists
                let chaptersURL = bookURL.deletingPathExtension().appendingPathExtension("chapters.json")
                try? fileManager.removeItem(at: chaptersURL)
                
                // Delete any encoding file if it exists
                let encodingURL = bookURL.deletingPathExtension().appendingPathExtension("encoding")
                try? fileManager.removeItem(at: encodingURL)
            } catch {
                print("Error deleting book: \(error.localizedDescription)")
            }
        }
        
        books.remove(atOffsets: offsets)
    }
}

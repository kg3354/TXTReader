import SwiftUI

struct BookReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = UserSettings.shared
    @State private var currentPage = 0
    @State private var pages: [String] = []
    @State private var isLoading = true
    @State private var showControls = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var visibleTextStart: String = ""
    @State private var visibleTextEnd: String = ""
    @State private var chapters: [Chapter] = []
    @State private var showChapterPicker = false
    
    let textContent: String
    let bookURL: URL
    
    private static var pageCache: [String: [String]] = [:]
    private static var chapterCache: [String: [Chapter]] = [:]
    
    @State private var bookBackgroundColor: Color = .white
    @State private var bookTextColor: Color = .black
    @State private var bookFontSize: Double = 18
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                bookBackgroundColor
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading...")
                } else {
                    ZStack {
                        // Page content
                        if !pages.isEmpty {
                            Text(pages[currentPage])
                                .font(.system(size: bookFontSize))
                                .foregroundColor(bookTextColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        // Three-part gesture zones
                        HStack(spacing: 0) {
                            // Left third - previous page
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    if showControls {
                                        showControls = false
                                        showChapterPicker = false
                                    } else {
                                        previousPage()
                                    }
                                }
                            
                            // Middle third - show/hide controls
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    withAnimation {
                                        if showControls {
                                            showControls = false
                                            showChapterPicker = false
                                        } else {
                                            showControls = true
                                        }
                                    }
                                }
                            
                            // Right third - next page
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    if showControls {
                                        showControls = false
                                        showChapterPicker = false
                                    } else {
                                        nextPage()
                                    }
                                }
                        }
                        // Add swipe gesture
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if !showControls {  // Only handle swipes when controls are hidden
                                        let threshold: CGFloat = 50
                                        if value.translation.width > threshold {
                                            previousPage()
                                        } else if value.translation.width < -threshold {
                                            nextPage()
                                        }
                                    }
                                }
                        )
                    }
                }
                
                // Controls overlay
                if showControls {
                    VStack {
                        // Top bar
                        HStack {
                            Button("Done") {
                                settings.setProgress(for: bookURL, page: currentPage)
                                dismiss()
                            }
                            
                            Spacer()
                            
                            // Add Chapter button
                            Button("Chapters") {
                                showChapterPicker.toggle()
                            }
                            
                            Spacer()
                            
                            Text("Page \(currentPage + 1) of \(pages.count)")
                                .font(.system(size: 14))
                            
                            Spacer()
                            
                            Button(action: {
                                showControls.toggle()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .padding()
                        .background(bookBackgroundColor.opacity(0.9))
                        
                        if showChapterPicker {
                            // Chapter picker
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(chapters) { chapter in
                                        Button(action: {
                                            currentPage = findPageForCharacterOffset(chapter.characterOffset)
                                            showChapterPicker = false
                                            showControls = false
                                        }) {
                                            Text(chapter.title)
                                                .foregroundColor(bookTextColor)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Divider()
                                            .background(bookTextColor)
                                    }
                                }
                                .padding()
                            }
                            .frame(maxHeight: geometry.size.height * 0.4)
                            .background(bookBackgroundColor)
                            .cornerRadius(15)
                            .padding()
                        }
                        
                        Spacer()
                        
                        // Settings panel
                        VStack(spacing: 12) {
                            // Font size controls
                            HStack {
                                Button(action: {
                                    bookFontSize = max(12, bookFontSize - 2)
                                    settings.setBookSettings(
                                        for: bookURL,
                                        backgroundColor: bookBackgroundColor,
                                        textColor: bookTextColor,
                                        fontSize: bookFontSize
                                    )
                                    calculatePages(for: UIScreen.main.bounds.size)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                }
                                
                                Spacer()
                                Text("Size: \(Int(bookFontSize))")
                                Spacer()
                                
                                Button(action: {
                                    bookFontSize = min(36, bookFontSize + 2)
                                    settings.setBookSettings(
                                        for: bookURL,
                                        backgroundColor: bookBackgroundColor,
                                        textColor: bookTextColor,
                                        fontSize: bookFontSize
                                    )
                                    calculatePages(for: UIScreen.main.bounds.size)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                }
                            }
                            
                            HStack {
                                Text("Text Color")
                                Spacer()
                                ColorPicker("", selection: $bookTextColor)
                                    .onChange(of: bookTextColor) { newValue in
                                        settings.setBookSettings(
                                            for: bookURL,
                                            backgroundColor: bookBackgroundColor,
                                            textColor: newValue,
                                            fontSize: bookFontSize
                                        )
                                    }
                            }
                            
                            HStack {
                                Text("Background")
                                Spacer()
                                ColorPicker("", selection: $bookBackgroundColor)
                                    .onChange(of: bookBackgroundColor) { newValue in
                                        settings.setBookSettings(
                                            for: bookURL,
                                            backgroundColor: newValue,
                                            textColor: bookTextColor,
                                            fontSize: bookFontSize
                                        )
                                    }
                            }
                        }
                        .padding()
                        .background(bookBackgroundColor.opacity(0.9))
                        .cornerRadius(15)
                        .padding()
                    }
                    .foregroundColor(bookTextColor)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            let (bg, txt, size) = settings.getBookSettings(for: bookURL)
            bookBackgroundColor = bg
            bookTextColor = txt
            bookFontSize = size
            let savedPage = settings.getProgress(for: bookURL)
            calculatePages(for: UIScreen.main.bounds.size)
            chapters = parseChapters(from: textContent)
            currentPage = min(savedPage, pages.count - 1)
        }
        .onChange(of: bookFontSize) { _ in
            calculatePages(for: UIScreen.main.bounds.size)
        }
    }
    
    private func calculatePages(for screenSize: CGSize) {
        let cacheKey = "\(bookURL.lastPathComponent)_\(bookFontSize)"
        
        // Try memory cache first
        if let cachedPages = BookReaderView.pageCache[cacheKey] {
            self.pages = cachedPages
            self.isLoading = false
            return
        }
        
        // Try disk cache next
        if let diskCachedPages = loadCachedPages(for: bookURL, fontSize: bookFontSize) {
            self.pages = diskCachedPages
            BookReaderView.pageCache[cacheKey] = diskCachedPages
            self.isLoading = false
            return
        }
        
        // Calculate pages if no cache exists
        isLoading = true
        
        let currentOffset = pages.isEmpty ? 0 : pages[..<currentPage].joined().count
        
        let storage = NSTextStorage()
        let container = NSTextContainer()
        let layoutManager = NSLayoutManager()
        
        // Adjust container size to use more of the screen height
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 32
        
        container.size = CGSize(
            width: screenSize.width - horizontalPadding,
            height: screenSize.height - verticalPadding
        )
        container.lineFragmentPadding = 0
        
        // Enable hyphenation and proper line breaking
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.hyphenationFactor = 1.0
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .natural
        
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.hyphenationFactor = 1.0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        
        let attributedString = NSAttributedString(
            string: textContent,
            attributes: [
                .font: UIFont.systemFont(ofSize: bookFontSize),
                .paragraphStyle: paragraphStyle
            ]
        )
        storage.setAttributedString(attributedString)
        
        var pages: [String] = []
        var currentPosition: Int = 0
        var newPageIndex = 0
        var totalCharacters = 0
        
        while currentPosition < storage.length {
            let glyphRange = layoutManager.glyphRange(
                forBoundingRect: CGRect(origin: .zero, size: container.size),
                in: container
            )
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            let pageRange = (storage.string as NSString).paragraphRange(for: NSRange(
                location: currentPosition,
                length: min(characterRange.length, storage.length - currentPosition)
            ))
            
            let pageText = (storage.string as NSString).substring(with: pageRange)
            
            // Track total characters and find the page containing our previous position
            if totalCharacters <= currentOffset && totalCharacters + pageText.count > currentOffset {
                newPageIndex = pages.count
            }
            
            totalCharacters += pageText.count
            pages.append(pageText)
            currentPosition += pageRange.length
        }
        
        self.pages = pages
        self.currentPage = min(newPageIndex, pages.count - 1)
        self.isLoading = false
        
        // Save to both memory and disk cache
        BookReaderView.pageCache[cacheKey] = pages
        savePagesToCache(pages, for: bookURL, fontSize: bookFontSize)
    }
    
    private func nextPage() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            settings.setProgress(for: bookURL, page: currentPage)
        }
    }
    
    private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
            settings.setProgress(for: bookURL, page: currentPage)
        }
    }
    
    private func parseChapters(from text: String) -> [Chapter] {
        if let cachedChapters = BookReaderView.chapterCache[bookURL.lastPathComponent] {
            return cachedChapters
        }
        
        var chapters: [Chapter] = []
        let pattern = "^(Chapter|CHAPTER|第)\\s*[0-9一二三四五六七八九十百千]+.*$"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let title = String(text[range])
                    let characterOffset = text.distance(from: text.startIndex, to: range.lowerBound)
                    chapters.append(Chapter(title: title, characterOffset: characterOffset))
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        BookReaderView.chapterCache[bookURL.lastPathComponent] = chapters
        return chapters
    }
    
    private func findPageForCharacterOffset(_ targetOffset: Int) -> Int {
        var currentOffset = 0
        for (index, page) in pages.enumerated() {
            if currentOffset <= targetOffset && currentOffset + page.count > targetOffset {
                return index
            }
            currentOffset += page.count
        }
        return 0
    }
    
    private func getCacheURL(for bookURL: URL, fontSize: Double) -> URL {
        let cacheFileName = "\(bookURL.lastPathComponent)_\(fontSize).pages"
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDirectory.appendingPathComponent(cacheFileName)
    }
    
    private func loadCachedPages(for bookURL: URL, fontSize: Double) -> [String]? {
        let cacheURL = getCacheURL(for: bookURL, fontSize: fontSize)
        if let data = try? Data(contentsOf: cacheURL),
           let pages = try? JSONDecoder().decode([String].self, from: data) {
            return pages
        }
        return nil
    }
    
    private func savePagesToCache(_ pages: [String], for bookURL: URL, fontSize: Double) {
        let cacheURL = getCacheURL(for: bookURL, fontSize: fontSize)
        if let data = try? JSONEncoder().encode(pages) {
            try? data.write(to: cacheURL)
        }
    }
}

// Helper extension
extension Substring {
    var string: String {
        String(self)
    }
}

// Preview provider for testing
struct BookReaderView_Previews: PreviewProvider {
    static var previews: some View {
        BookReaderView(textContent: "This is a sample text for preview purposes. It should be long enough to demonstrate scrolling.", bookURL: URL(fileURLWithPath: ""))
    }
}

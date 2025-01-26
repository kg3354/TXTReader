import SwiftUI

@MainActor
final class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // Default settings for the main page
    @AppStorage("mainBackgroundColor") private var mainBackgroundColorData: Data?
    @AppStorage("mainTextColor") private var mainTextColorData: Data?
    
    // Per-book settings
    @AppStorage("bookSettings") private var bookSettingsData: Data?
    private var bookSettings: [String: BookSettings] = [:]
    
    @Published private(set) var backgroundColor: Color = .white
    @Published private(set) var textColor: Color = .black
    @Published var fontSize: Double = 18
    
    struct BookSettings: Codable {
        var backgroundColor: Data
        var textColor: Data
        var fontSize: Double
        var lastPage: Int
    }
    
    private init() {
        loadMainColors()
        loadBookSettings()
    }
    
    private func loadMainColors() {
        if let data = mainBackgroundColorData,
           let color = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
            backgroundColor = Color(color)
        }
        
        if let data = mainTextColorData,
           let color = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
            textColor = Color(color)
        }
    }
    
    private func loadBookSettings() {
        if let data = bookSettingsData,
           let decoded = try? JSONDecoder().decode([String: BookSettings].self, from: data) {
            bookSettings = decoded
        }
    }
    
    private func saveBookSettings() {
        if let encoded = try? JSONEncoder().encode(bookSettings) {
            bookSettingsData = encoded
            UserDefaults.standard.synchronize()
        }
    }
    
    // Get settings for a specific book
    func getBookSettings(for url: URL) -> (Color, Color, Double) {
        let key = url.lastPathComponent
        if let settings = bookSettings[key],
           let bgColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(settings.backgroundColor) as? UIColor,
           let txtColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(settings.textColor) as? UIColor {
            return (Color(bgColor), Color(txtColor), settings.fontSize)
        }
        return (.white, .black, 18) // Default settings
    }
    
    // Set settings for a specific book
    func setBookSettings(for url: URL, backgroundColor: Color, textColor: Color, fontSize: Double) {
        let key = url.lastPathComponent
        let bgData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(backgroundColor), requiringSecureCoding: true)
        let txtData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(textColor), requiringSecureCoding: true)
        
        if let bgData = bgData, let txtData = txtData {
            let settings = BookSettings(
                backgroundColor: bgData,
                textColor: txtData,
                fontSize: fontSize,
                lastPage: bookSettings[key]?.lastPage ?? 0
            )
            bookSettings[key] = settings
            saveBookSettings()
        }
    }
    
    // Progress tracking
    func getProgress(for url: URL) -> Int {
        return bookSettings[url.lastPathComponent]?.lastPage ?? 0
    }
    
    func setProgress(for url: URL, page: Int) {
        let key = url.lastPathComponent
        if var settings = bookSettings[key] {
            settings.lastPage = page
            bookSettings[key] = settings
        } else {
            // Create new settings with defaults if none exist
            let bgData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor.white, requiringSecureCoding: true)
            let txtData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor.black, requiringSecureCoding: true)
            if let bgData = bgData, let txtData = txtData {
                bookSettings[key] = BookSettings(
                    backgroundColor: bgData,
                    textColor: txtData,
                    fontSize: 18,
                    lastPage: page
                )
            }
        }
        saveBookSettings()
        objectWillChange.send()
    }
}

// Extension to make UserSettings Sendable
extension UserSettings: @unchecked Sendable {} 

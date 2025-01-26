import Foundation

struct Chapter: Identifiable, Codable {
    let id: UUID
    let title: String
    let characterOffset: Int

    init(id: UUID = UUID(), title: String, characterOffset: Int) {
        self.id = id
        self.title = title
        self.characterOffset = characterOffset
    }
}

import Foundation
import GRDB

struct Clip: Identifiable, Equatable {
    var id: Int64?
    var content: String
    var contentType: String // "text" or "image"
    var createdAt: Int      // Unix timestamp
    var pinned: Bool

    var isImage: Bool { contentType == "image" }

    func relativeTimeString() -> String {
        let date = Date(timeIntervalSince1970: Double(createdAt))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension Clip: FetchableRecord {
    init(row: Row) {
        id = row["id"]
        content = row["content"]
        let ct: String? = row["content_type"]
        contentType = ct ?? "text"
        createdAt = row["created_at"]
        // Bool? subscript: GRDB decodes SQLite integer 0/1 → false/true
        let p: Bool? = row["pinned"]
        pinned = p ?? false
    }
}

extension Clip: MutablePersistableRecord {
    static let databaseTableName = "clips"

    func encode(to container: inout PersistenceContainer) {
        container["content"] = content
        container["content_type"] = contentType
        container["created_at"] = createdAt
        container["pinned"] = pinned
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

import Foundation
import GRDB
import AppKit
import CryptoKit

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var clips: [Clip] = []
    @Published private(set) var dbError: String? = nil

    private var dbQueue: DatabaseQueue!
    private var cancellable: AnyDatabaseCancellable?
    private var cryptoKey: SymmetricKey?

    /// Internal override used only in unit tests to bypass the 100–1000 clamp.
    var _historyLimitOverride: Int? = nil

    var historyLimit: Int {
        get {
            if let override = _historyLimitOverride { return override }
            let v = UserDefaults.standard.integer(forKey: "historyLimit")
            return v == 0 ? 1000 : max(100, min(1000, v))
        }
        set {
            _historyLimitOverride = nil  // Clear override when setting real value
            UserDefaults.standard.set(max(100, min(1000, newValue)), forKey: "historyLimit")
        }
    }

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Clipstasher", isDirectory: true)
    }()

    static let imagesDir: URL = appSupportDir.appendingPathComponent("images", isDirectory: true)
    static let dbURL: URL = appSupportDir.appendingPathComponent("clips.sqlite")

    // MARK: - Initializers

    private init() {
        do {
            try FileManager.default.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: Self.imagesDir, withIntermediateDirectories: true)
            dbQueue = try DatabaseQueue(path: Self.dbURL.path)
            try applyMigrations(dbQueue)
            cryptoKey = try? ClipCrypto.loadOrCreateKey()
            startObservation()
        } catch {
            handleMigrationFailure(error: error)
        }
    }

    /// For unit tests — takes a pre-configured in-memory DatabaseQueue.
    init(_testQueue: DatabaseQueue) throws {
        self.dbQueue = _testQueue
        try applyMigrations(dbQueue)
        cryptoKey = try? ClipCrypto.loadOrCreateKey()
        startObservation()
    }

    // MARK: - Schema migrations

    private func applyMigrations(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "clips") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("content_type", .text).notNull().defaults(to: "text")
                t.column("created_at", .integer).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "clips_on_created_at", on: "clips", columns: ["created_at"])
        }
        try migrator.migrate(db)
    }

    // MARK: - Reactive observation

    private func startObservation() {
        guard let dbQueue else { return }
        let observation = ValueObservation.tracking { db in
            try Clip.order(Column("created_at").desc, Column("id").desc).fetchAll(db)
        }
        cancellable = observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { [weak self] error in
                self?.dbError = error.localizedDescription
            },
            onChange: { [weak self] clips in
                guard let self else { return }
                if let key = self.cryptoKey {
                    self.clips = clips.map { c in
                        var d = c; d.content = ClipCrypto.decrypt(c.content, key: key); return d
                    }
                } else {
                    self.clips = clips
                }
            }
        )
    }

    // MARK: - Write operations

    func insert(content: String, contentType: String = "text") async {
        guard let dbQueue else { return }
        let limit = historyLimit
        let key = cryptoKey
        await Task.detached(priority: .userInitiated) {
            try? dbQueue.write { db in
                // Dedup: compare decrypted stored content vs incoming plaintext.
                // ClipCrypto.decrypt passes through non-prefixed strings, so this
                // works for both legacy plaintext and encrypted rows.
                if let lastStored = try? String.fetchOne(db, sql: "SELECT content FROM clips ORDER BY id DESC LIMIT 1") {
                    let lastPlain = key.map { ClipCrypto.decrypt(lastStored, key: $0) } ?? lastStored
                    if lastPlain == content { return }
                }

                let stored: String
                if let key, contentType == "text" {
                    stored = (try? ClipCrypto.encrypt(content, key: key)) ?? content
                } else {
                    stored = content
                }

                var clip = Clip(
                    id: nil,
                    content: stored,
                    contentType: contentType,
                    createdAt: Int(Date().timeIntervalSince1970),
                    pinned: false
                )
                try clip.insert(db)

                // Prune non-pinned overflow
                try db.execute(
                    sql: """
                    DELETE FROM clips
                    WHERE pinned = 0
                    AND id NOT IN (
                        SELECT id FROM clips WHERE pinned = 0
                        ORDER BY created_at DESC
                        LIMIT ?
                    )
                    """,
                    arguments: [limit]
                )
            }
        }.value
    }

    func insertImage(data: Data) async -> Bool {
        guard
            let bitmapRep = NSBitmapImageRep(data: data),
            let pngData = bitmapRep.representation(using: .png, properties: [:])
        else { return false }

        let imageURL = Self.imagesDir.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try pngData.write(to: imageURL)
        } catch { return false }

        await insert(content: imageURL.path, contentType: "image")
        return true
    }

    func togglePin(id: Int64) async {
        guard let dbQueue else { return }
        await Task.detached(priority: .userInitiated) {
            try? dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE clips SET pinned = NOT pinned WHERE id = ?",
                    arguments: [id]
                )
            }
        }.value
    }

    func delete(id: Int64) async {
        guard let dbQueue else { return }
        await Task.detached(priority: .userInitiated) {
            try? dbQueue.write { db in
                if let clip = try Clip.fetchOne(db, sql: "SELECT * FROM clips WHERE id = ?", arguments: [id]),
                   clip.isImage {
                    try? FileManager.default.removeItem(atPath: clip.content)
                }
                try db.execute(sql: "DELETE FROM clips WHERE id = ?", arguments: [id])
            }
        }.value
    }

    func clearAll() async {
        guard let dbQueue else { return }
        await Task.detached(priority: .userInitiated) {
            try? dbQueue.write { db in
                let imagePaths = try String.fetchAll(
                    db,
                    sql: "SELECT content FROM clips WHERE pinned = 0 AND content_type = 'image'"
                )
                for path in imagePaths {
                    try? FileManager.default.removeItem(atPath: path)
                }
                try db.execute(sql: "DELETE FROM clips WHERE pinned = 0")
            }
        }.value
    }

    // MARK: - Clipboard write

    func copyToClipboard(_ clip: Clip) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if clip.isImage, let image = NSImage(contentsOfFile: clip.content) {
            pb.writeObjects([image])
        } else {
            pb.setString(clip.content, forType: .string)
        }
        ClipboardMonitor.shared.markSelfWrite()
    }

    // MARK: - About tab helpers

    func binarySHA256() -> String {
        guard let url = Bundle.main.executableURL,
              let data = try? Data(contentsOf: url) else { return "unavailable" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func openDataFolder() {
        NSWorkspace.shared.open(Self.appSupportDir)
    }

    /// Direct DB read — for unit tests that can't wait for async observation.
    func fetchAllDirect() async throws -> [Clip] {
        guard let db = dbQueue else { return [] }
        let key = cryptoKey
        return try await Task.detached {
            let clips = try db.read { try Clip.order(Column("created_at").desc, Column("id").desc).fetchAll($0) }
            guard let key else { return clips }
            return clips.map { c in var d = c; d.content = ClipCrypto.decrypt(c.content, key: key); return d }
        }.value
    }

    // MARK: - Migration failure

    private func handleMigrationFailure(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Clipstasher Can't Open Your Clips"
        alert.informativeText = """
        The database at \(Self.dbURL.path) could not be opened.

        You can start fresh (the corrupted file will be renamed and preserved) or quit the app.

        Report issues at https://github.com/ShreyRavi/clipstasher/issues
        """
        alert.addButton(withTitle: "Start Fresh")
        alert.addButton(withTitle: "Quit")
        alert.alertStyle = .critical

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let backup = Self.dbURL.deletingLastPathComponent()
                .appendingPathComponent("clips.sqlite.bak.\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: Self.dbURL, to: backup)
            do {
                dbQueue = try DatabaseQueue(path: Self.dbURL.path)
                try applyMigrations(dbQueue)
                startObservation()
            } catch {
                NSApplication.shared.terminate(nil)
            }
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
}

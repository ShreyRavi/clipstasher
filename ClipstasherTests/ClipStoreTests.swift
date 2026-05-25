import XCTest
import GRDB
@testable import Clipstasher

@MainActor
final class ClipStoreTests: XCTestCase {

    var store: ClipStore!

    override func setUp() async throws {
        store = try ClipStore(_testQueue: DatabaseQueue())
    }

    // MARK: - Schema

    func testSchemaCreated() {
        XCTAssertNotNil(store)
    }

    // MARK: - fetchAllDirect

    func testFetchAllDirectEmpty() async throws {
        let clips = try await store.fetchAllDirect()
        XCTAssertTrue(clips.isEmpty)
    }

    // MARK: - Insert text

    func testInsertTextClip() async throws {
        await store.insert(content: "hello world")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].content, "hello world")
        XCTAssertEqual(clips[0].contentType, "text")
        XCTAssertFalse(clips[0].pinned)
    }

    func testConsecutiveDedup() async throws {
        await store.insert(content: "dup")
        await store.insert(content: "dup")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips.count, 1, "Second identical consecutive insert must be skipped")
    }

    func testNonConsecutiveDupAllowed() async throws {
        await store.insert(content: "a")
        await store.insert(content: "b")
        await store.insert(content: "a")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips.count, 3)
    }

    func testCreatedAtTimestamp() async throws {
        let before = Int(Date().timeIntervalSince1970)
        await store.insert(content: "ts test")
        let after = Int(Date().timeIntervalSince1970)
        let clips = try await store.fetchAllDirect()
        XCTAssertGreaterThanOrEqual(clips[0].createdAt, before)
        XCTAssertLessThanOrEqual(clips[0].createdAt, after)
    }

    func testContentTypeDefaultsToText() async throws {
        await store.insert(content: "no type")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips[0].contentType, "text")
    }

    func testInsertExplicitContentType() async throws {
        await store.insert(content: "/tmp/test.png", contentType: "image")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips[0].contentType, "image")
        XCTAssertTrue(clips[0].isImage)
    }

    // MARK: - Pin

    func testTogglePin() async throws {
        await store.insert(content: "pin me")
        let before = try await store.fetchAllDirect()
        let id = try XCTUnwrap(before.first?.id)
        await store.togglePin(id: id)
        let after = try await store.fetchAllDirect()
        XCTAssertTrue(after[0].pinned)
        await store.togglePin(id: id)
        let after2 = try await store.fetchAllDirect()
        XCTAssertFalse(after2[0].pinned)
    }

    func testTogglePinUnknownIdNoOp() async throws {
        await store.insert(content: "real clip")
        await store.togglePin(id: 999_999)
        let clips = try await store.fetchAllDirect()
        XCTAssertFalse(clips[0].pinned, "Unknown id should be a no-op")
    }

    // MARK: - Delete

    func testDelete() async throws {
        await store.insert(content: "to delete")
        let clips = try await store.fetchAllDirect()
        let id = try XCTUnwrap(clips.first?.id)
        await store.delete(id: id)
        let after = try await store.fetchAllDirect()
        XCTAssertEqual(after.count, 0)
    }

    func testDeleteUnknownIdNoOp() async throws {
        await store.insert(content: "stays")
        await store.delete(id: 999_999)
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips.count, 1)
    }

    func testDeleteImageClipCleansUpFile() async throws {
        try FileManager.default.createDirectory(at: ClipStore.imagesDir, withIntermediateDirectories: true)
        let tiffData = makeTIFFData()
        let inserted = await store.insertImage(data: tiffData)
        XCTAssertTrue(inserted)

        let clips = try await store.fetchAllDirect()
        let imageClip = try XCTUnwrap(clips.first(where: { $0.isImage }))
        let path = imageClip.content
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Image file should exist after insert")

        let id = try XCTUnwrap(imageClip.id)
        await store.delete(id: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Image file should be removed after delete")
    }

    // MARK: - Clear All

    func testClearAllPreservesPinned() async throws {
        await store.insert(content: "pinned clip")
        await store.insert(content: "normal clip")
        let clips = try await store.fetchAllDirect()
        let pinnedId = try XCTUnwrap(clips.min(by: { $0.id! < $1.id! })?.id)
        await store.togglePin(id: pinnedId)
        await store.clearAll()
        let after = try await store.fetchAllDirect()
        XCTAssertEqual(after.count, 1)
        XCTAssertTrue(after[0].pinned)
        XCTAssertEqual(after[0].content, "pinned clip")
    }

    func testClearAllEmptyNoOp() async throws {
        await store.clearAll()
        let clips = try await store.fetchAllDirect()
        XCTAssertTrue(clips.isEmpty)
    }

    func testClearAllDeletesImageFiles() async throws {
        try FileManager.default.createDirectory(at: ClipStore.imagesDir, withIntermediateDirectories: true)
        let tiffData = makeTIFFData()
        let inserted = await store.insertImage(data: tiffData)
        XCTAssertTrue(inserted)

        let clips = try await store.fetchAllDirect()
        let imageClip = try XCTUnwrap(clips.first(where: { $0.isImage }))
        let path = imageClip.content
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        await store.clearAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "clearAll should delete image files")

        let remaining = try await store.fetchAllDirect()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testClearAllPreservesPinnedImageFile() async throws {
        try FileManager.default.createDirectory(at: ClipStore.imagesDir, withIntermediateDirectories: true)
        let tiffData = makeTIFFData()
        _ = await store.insertImage(data: tiffData)
        await store.insert(content: "text clip")

        let clips = try await store.fetchAllDirect()
        let imageClip = try XCTUnwrap(clips.first(where: { $0.isImage }))
        let id = try XCTUnwrap(imageClip.id)
        await store.togglePin(id: id)

        await store.clearAll()

        let after = try await store.fetchAllDirect()
        XCTAssertEqual(after.count, 1, "Pinned image clip should survive clearAll")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageClip.content), "Pinned image file should not be deleted")

        // Cleanup
        await store.togglePin(id: id)
        await store.clearAll()
        try? FileManager.default.removeItem(atPath: imageClip.content)
    }

    // MARK: - Prune

    func testPruneRespectsLimit() async throws {
        store._historyLimitOverride = 5
        for i in 1...10 {
            await store.insert(content: "clip \(i)")
        }
        let clips = try await store.fetchAllDirect()
        XCTAssertLessThanOrEqual(clips.filter { !$0.pinned }.count, 5)
    }

    func testPinnedSurvivesPrune() async throws {
        store._historyLimitOverride = 3
        await store.insert(content: "precious clip")
        let first = try await store.fetchAllDirect()
        await store.togglePin(id: first[0].id!)
        for i in 1...5 {
            await store.insert(content: "clip \(i)")
        }
        let after = try await store.fetchAllDirect()
        let pinned = after.filter { $0.pinned }
        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned[0].content, "precious clip")
    }

    func testPruneAllPinnedNoUnpinnedRemoved() async throws {
        store._historyLimitOverride = 2
        for i in 1...5 {
            await store.insert(content: "clip \(i)")
            let all = try await store.fetchAllDirect()
            if let id = all.first(where: { $0.content == "clip \(i)" })?.id {
                await store.togglePin(id: id)
            }
        }
        let all = try await store.fetchAllDirect()
        XCTAssertEqual(all.filter { $0.pinned }.count, 5, "All pinned clips must survive pruning")
    }

    // MARK: - historyLimit

    func testHistoryLimitDefaultsTo1000() {
        UserDefaults.standard.removeObject(forKey: "historyLimit")
        XCTAssertEqual(store.historyLimit, 1000)
    }

    func testHistoryLimitSetterClampsLow() {
        let original = UserDefaults.standard.integer(forKey: "historyLimit")
        defer { UserDefaults.standard.set(original == 0 ? nil : original, forKey: "historyLimit") }
        store.historyLimit = 50
        XCTAssertEqual(store.historyLimit, 100)
    }

    func testHistoryLimitSetterClampsHigh() {
        let original = UserDefaults.standard.integer(forKey: "historyLimit")
        defer { UserDefaults.standard.set(original == 0 ? nil : original, forKey: "historyLimit") }
        store.historyLimit = 2000
        XCTAssertEqual(store.historyLimit, 1000)
    }

    func testHistoryLimitSetterValidValue() {
        let original = UserDefaults.standard.integer(forKey: "historyLimit")
        defer { UserDefaults.standard.set(original == 0 ? nil : original, forKey: "historyLimit") }
        store.historyLimit = 500
        XCTAssertEqual(store.historyLimit, 500)
    }

    func testHistoryLimitOverrideBypassesClamp() {
        store._historyLimitOverride = 5
        XCTAssertEqual(store.historyLimit, 5)
    }

    func testHistoryLimitSetterClearsOverride() {
        store._historyLimitOverride = 2
        XCTAssertEqual(store.historyLimit, 2)
        store.historyLimit = 300
        XCTAssertNil(store._historyLimitOverride, "Setter must clear the override")
        XCTAssertEqual(store.historyLimit, 300)
    }

    // MARK: - insertImage

    func testInsertImageReturnsTrue() async throws {
        try FileManager.default.createDirectory(at: ClipStore.imagesDir, withIntermediateDirectories: true)
        let result = await store.insertImage(data: makeTIFFData())
        XCTAssertTrue(result)
        let clips = try await store.fetchAllDirect()
        let imageClip = clips.first(where: { $0.isImage })
        XCTAssertNotNil(imageClip)
        // Cleanup
        if let path = imageClip?.content { try? FileManager.default.removeItem(atPath: path) }
    }

    func testInsertImageInvalidDataReturnsFalse() async {
        let result = await store.insertImage(data: Data("not an image".utf8))
        XCTAssertFalse(result)
    }

    func testInsertImageContentType() async throws {
        try FileManager.default.createDirectory(at: ClipStore.imagesDir, withIntermediateDirectories: true)
        _ = await store.insertImage(data: makeTIFFData())
        let clips = try await store.fetchAllDirect()
        let imageClip = try XCTUnwrap(clips.first(where: { $0.isImage }))
        XCTAssertEqual(imageClip.contentType, "image")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageClip.content))
        // Cleanup
        try? FileManager.default.removeItem(atPath: imageClip.content)
    }

    // MARK: - copyToClipboard

    func testCopyToClipboardSetsString() async throws {
        await store.insert(content: "clipboard payload")
        let clips = try await store.fetchAllDirect()
        store.copyToClipboard(clips[0])
        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "clipboard payload")
    }

    func testCopyToClipboardMarksSelfWrite() async throws {
        await store.insert(content: "mark self")
        let clips = try await store.fetchAllDirect()
        store.copyToClipboard(clips[0])
        let expected = NSPasteboard.general.changeCount
        XCTAssertGreaterThanOrEqual(ClipboardMonitor.shared.lastSelfWriteChangeCount, expected - 1)
    }

    func testCopyToClipboardImageFallsBackToPathWhenFileMissing() {
        let clip = Clip(id: 1, content: "/nonexistent/path.png", contentType: "image",
                        createdAt: Int(Date().timeIntervalSince1970), pinned: false)
        store.copyToClipboard(clip)
        // File doesn't exist → falls back to writing the path as a string
        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "/nonexistent/path.png")
    }

    // MARK: - binarySHA256

    func testBinarySHA256ReturnsBundleHashOrUnavailable() {
        let hash = store.binarySHA256()
        let isHex64 = hash.count == 64 && hash.allSatisfy { $0.isHexDigit }
        XCTAssertTrue(isHex64 || hash == "unavailable",
                      "Expected 64-char hex or 'unavailable', got: \(hash)")
    }

    // MARK: - Sensitive content detection (via ClipStore insert)

    func testSensitiveDetectsOpenAIKey() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("sk-abcdefghijklmnopqrstuvwxyz01234567890A"))
    }

    func testSensitiveDetectsGithubToken() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh12"))
    }

    func testSensitiveDetectsBearerToken() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
    }

    func testSensitiveDetectsEnvVar() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("DATABASE_URL=postgres://user:pass@host/db"))
    }

    func testSensitiveNormalContent() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive("let x = 42"))
        XCTAssertFalse(SensitiveContentDetector.isSensitive("hello world"))
    }

    // MARK: - relativeTimeString

    func testRelativeTimeString() async throws {
        await store.insert(content: "time test")
        let clips = try await store.fetchAllDirect()
        XCTAssertFalse(clips[0].relativeTimeString().isEmpty)
    }

    // MARK: - Helpers

    private func makeTIFFData() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 8,
            bitsPerPixel: 32
        )!
        return rep.tiffRepresentation!
    }
}

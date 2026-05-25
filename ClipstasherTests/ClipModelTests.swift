import XCTest
import GRDB
@testable import Clipstasher

final class ClipModelTests: XCTestCase {

    // MARK: - isImage

    func testIsImageTrueForImageType() {
        let clip = Clip(id: nil, content: "/tmp/img.png", contentType: "image",
                        createdAt: 0, pinned: false)
        XCTAssertTrue(clip.isImage)
    }

    func testIsImageFalseForTextType() {
        let clip = Clip(id: nil, content: "hello", contentType: "text",
                        createdAt: 0, pinned: false)
        XCTAssertFalse(clip.isImage)
    }

    func testIsImageFalseForUnknownType() {
        let clip = Clip(id: nil, content: "x", contentType: "unknown",
                        createdAt: 0, pinned: false)
        XCTAssertFalse(clip.isImage)
    }

    // MARK: - Equatable

    func testEqualityWithSameValues() {
        let c1 = Clip(id: 1, content: "hello", contentType: "text", createdAt: 1000, pinned: false)
        let c2 = Clip(id: 1, content: "hello", contentType: "text", createdAt: 1000, pinned: false)
        XCTAssertEqual(c1, c2)
    }

    func testInequalityDifferentContent() {
        let c1 = Clip(id: 1, content: "hello", contentType: "text", createdAt: 1000, pinned: false)
        let c2 = Clip(id: 1, content: "world", contentType: "text", createdAt: 1000, pinned: false)
        XCTAssertNotEqual(c1, c2)
    }

    func testInequalityDifferentPinnedState() {
        let c1 = Clip(id: 1, content: "x", contentType: "text", createdAt: 1000, pinned: false)
        let c2 = Clip(id: 1, content: "x", contentType: "text", createdAt: 1000, pinned: true)
        XCTAssertNotEqual(c1, c2)
    }

    func testInequalityDifferentID() {
        let c1 = Clip(id: 1, content: "x", contentType: "text", createdAt: 1000, pinned: false)
        let c2 = Clip(id: 2, content: "x", contentType: "text", createdAt: 1000, pinned: false)
        XCTAssertNotEqual(c1, c2)
    }

    func testEqualityWithNilID() {
        let c1 = Clip(id: nil, content: "x", contentType: "text", createdAt: 0, pinned: false)
        let c2 = Clip(id: nil, content: "x", contentType: "text", createdAt: 0, pinned: false)
        XCTAssertEqual(c1, c2)
    }

    // MARK: - Identifiable

    func testIdentifiableUsesOptionalInt64() {
        let clip = Clip(id: 42, content: "x", contentType: "text", createdAt: 0, pinned: false)
        XCTAssertEqual(clip.id, 42)
    }

    // MARK: - relativeTimeString

    func testRelativeTimeStringNotEmpty() {
        let clip = Clip(id: nil, content: "x", contentType: "text",
                        createdAt: Int(Date().timeIntervalSince1970), pinned: false)
        XCTAssertFalse(clip.relativeTimeString().isEmpty)
    }

    func testRelativeTimeStringForRecentClip() {
        let clip = Clip(id: nil, content: "x", contentType: "text",
                        createdAt: Int(Date().timeIntervalSince1970), pinned: false)
        let s = clip.relativeTimeString()
        // RelativeDateTimeFormatter with .abbreviated returns something like "now" or "0 sec. ago"
        XCTAssertFalse(s.isEmpty)
    }

    func testRelativeTimeStringForOneHourAgo() {
        let createdAt = Int(Date().timeIntervalSince1970) - 3600
        let clip = Clip(id: nil, content: "x", contentType: "text",
                        createdAt: createdAt, pinned: false)
        let s = clip.relativeTimeString()
        XCTAssertFalse(s.isEmpty)
        // Locale-independent check: must contain "1" and some hour indicator
        XCTAssertTrue(s.contains("1"), "1 hour ago string should contain '1': \(s)")
    }

    // MARK: - FetchableRecord / MutablePersistableRecord round-trip

    @MainActor
    func testRoundTripTextClip() async throws {
        let store = try ClipStore(_testQueue: DatabaseQueue())
        await store.insert(content: "round trip", contentType: "text")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].content, "round trip")
        XCTAssertEqual(clips[0].contentType, "text")
        XCTAssertFalse(clips[0].pinned)
        XCTAssertNotNil(clips[0].id)
    }

    @MainActor
    func testRoundTripImageClip() async throws {
        let store = try ClipStore(_testQueue: DatabaseQueue())
        await store.insert(content: "/tmp/img.png", contentType: "image")
        let clips = try await store.fetchAllDirect()
        XCTAssertEqual(clips[0].contentType, "image")
        XCTAssertTrue(clips[0].isImage)
    }

    @MainActor
    func testRoundTripPinnedClip() async throws {
        let store = try ClipStore(_testQueue: DatabaseQueue())
        await store.insert(content: "pinned")
        let all = try await store.fetchAllDirect()
        let id = try XCTUnwrap(all[0].id)
        await store.togglePin(id: id)
        let after = try await store.fetchAllDirect()
        XCTAssertTrue(after[0].pinned)
    }

    @MainActor
    func testDidInsertSetsID() async throws {
        let store = try ClipStore(_testQueue: DatabaseQueue())
        await store.insert(content: "id test")
        let clips = try await store.fetchAllDirect()
        XCTAssertNotNil(clips[0].id)
        XCTAssertGreaterThan(clips[0].id!, 0)
    }
}

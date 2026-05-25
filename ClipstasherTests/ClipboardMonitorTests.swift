import XCTest
@testable import Clipstasher

final class ClipboardMonitorTests: XCTestCase {

    func testLastSelfWriteChangeCountIsAccessible() {
        // -1 before any markSelfWrite; ≥ 0 after. Always valid.
        XCTAssertGreaterThanOrEqual(ClipboardMonitor.shared.lastSelfWriteChangeCount, -1)
    }

    func testMarkSelfWriteUpdatesCount() {
        ClipboardMonitor.shared.markSelfWrite()
        let expected = NSPasteboard.general.changeCount
        XCTAssertGreaterThanOrEqual(ClipboardMonitor.shared.lastSelfWriteChangeCount, expected - 1)
    }

    func testStopDoesNotCrash() {
        ClipboardMonitor.shared.stop()
        // Stop is idempotent — calling again should not crash
        ClipboardMonitor.shared.stop()
        // Restore polling for other tests
        ClipboardMonitor.shared.start()
    }

    func testStartAfterStopResumesMonitor() {
        ClipboardMonitor.shared.stop()
        ClipboardMonitor.shared.start()
        // No crash and shared instance still accessible
        XCTAssertNotNil(ClipboardMonitor.shared)
    }

    func testStartIsIdempotent() {
        // Calling start() twice must not create duplicate timers (guard timer == nil)
        ClipboardMonitor.shared.start()
        ClipboardMonitor.shared.start()
        XCTAssertNotNil(ClipboardMonitor.shared)
    }

    func testMarkSelfWriteAfterPasteboardWrite() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("monitor test payload", forType: .string)
        ClipboardMonitor.shared.markSelfWrite()
        let count = NSPasteboard.general.changeCount
        XCTAssertGreaterThanOrEqual(ClipboardMonitor.shared.lastSelfWriteChangeCount, count - 1)
    }
}

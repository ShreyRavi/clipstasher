import AppKit
import Foundation

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int
    private(set) var lastSelfWriteChangeCount: Int = -1

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount

        // App Nap prevention — keeps timer firing at full rate in background
        ProcessInfo.processInfo.disableAutomaticTermination("clipboard monitoring")
        _ = ProcessInfo.processInfo.beginActivity(
            options: [.latencyCritical, .automaticTerminationDisabled],
            reason: "clipboard monitoring"
        )

        start()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(poll),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call immediately after writing to NSPasteboard so the monitor skips our own write.
    func markSelfWrite() {
        lastSelfWriteChangeCount = NSPasteboard.general.changeCount
    }

    @objc private func poll() {
        let current = NSPasteboard.general.changeCount

        // Overflow guard: changeCount is an Int and wraps rarely but handle it gracefully
        if current < lastChangeCount {
            lastChangeCount = current
            return
        }

        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Skip content we wrote ourselves (click-to-copy re-entry guard)
        guard current != lastSelfWriteChangeCount else { return }

        processNewContent()
    }

    private func processNewContent() {
        let pb = NSPasteboard.general

        // Prefer image over plain text when both are present
        if let tiffData = pb.data(forType: .tiff) {
            Task { @MainActor in
                _ = await ClipStore.shared.insertImage(data: tiffData)
            }
            return
        }

        // PNG data
        if let pngData = pb.data(forType: .png) {
            Task { @MainActor in
                _ = await ClipStore.shared.insertImage(data: pngData)
            }
            return
        }

        // Plain text
        if let string = pb.string(forType: .string), !string.isEmpty {
            Task { @MainActor in
                await ClipStore.shared.insert(content: string)
            }
        }
    }
}

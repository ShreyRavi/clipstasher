import SwiftUI
import AppKit
import ApplicationServices

struct ClipstasherView: View {
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var appDelegate: AppDelegate
    @State private var searchText = ""
    @State private var confirmingClear = false
    @State private var feedbackText: String? = nil
    @State private var feedbackWorkItem: DispatchWorkItem? = nil

    // UserDefaults-backed: true = paste (default), false = copy only
    @AppStorage("clickToPaste") private var clickToPaste = true

    private var filteredClips: [Clip] {
        guard !searchText.isEmpty else { return store.clips }
        return store.clips.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            searchBar
            Divider()
            clipList
            Divider()
            footerBar
        }
        .frame(width: 320, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            confirmingClear = false
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Text("Clipstasher")
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
            Spacer()
            settingsButton
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private var settingsButton: some View {
        Button {
            // Close the floating panel first so the settings window isn't hidden beneath it
            NSApplication.shared.keyWindow?.close()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appDelegate.openSettings()
            }
        } label: {
            Image(systemName: "gear")
                .font(.system(size: 16))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            TextField("Search clips…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
    }

    // MARK: - Clip list

    @ViewBuilder
    private var clipList: some View {
        if store.clips.isEmpty {
            emptyState
        } else if filteredClips.isEmpty {
            searchEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredClips.enumerated()), id: \.element.id) { idx, clip in
                        ClipItemRow(
                            clip: clip,
                            onCopy: { handleClipAction(clip) },
                            onPin: {
                                Task { await store.togglePin(id: clip.id!) }
                            }
                        )

                        if idx < filteredClips.count - 1 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("No clips yet. Start copying.")
                .font(.body)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("No results for \"\(searchText)\"")
                .font(.body)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if confirmingClear {
                // Inline confirmation — no modal sheet (sheets are unreliable in floating panels)
                Text("Clear \(store.clips.filter { !$0.pinned }.count) clips?")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Button("Cancel") {
                    confirmingClear = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                Button("Clear All") {
                    confirmingClear = false
                    Task { await store.clearAll() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(Color(nsColor: .systemRed))
            } else if let feedback = feedbackText {
                // Transient copy/paste feedback
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .transition(.opacity)
                Spacer()
                Text("\(store.clips.count) clips")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            } else {
                Button("Clear All") {
                    confirmingClear = true
                }
                .font(.body)
                .foregroundColor(Color(nsColor: .systemRed))
                .buttonStyle(.plain)
                .disabled(store.clips.filter { !$0.pinned }.isEmpty)

                Spacer()

                Text("\(store.clips.count) clips")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .animation(.easeOut(duration: 0.15), value: confirmingClear)
        .animation(.easeOut(duration: 0.15), value: feedbackText)
    }

    // MARK: - Clip action (copy or paste)

    private func handleClipAction(_ clip: Clip) {
        store.copyToClipboard(clip)

        if clickToPaste {
            // Require Accessibility permission — CGEvent.post silently fails without it
            let trusted = AXIsProcessTrustedWithOptions(
                ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            )
            if trusted {
                NSApplication.shared.keyWindow?.close()
                simulatePaste()
            } else {
                // Permission dialog shown; fall back to copy-only this time
                feedbackWorkItem?.cancel()
                withAnimation { feedbackText = "Grant Accessibility access to paste" }
                let item = DispatchWorkItem {
                    withAnimation { feedbackText = nil }
                    NSApplication.shared.keyWindow?.close()
                }
                feedbackWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
            }
        } else {
            // Show "Copied!" in footer for 1 second, then close (cancel any pending dismiss)
            feedbackWorkItem?.cancel()
            withAnimation { feedbackText = "Copied!" }
            let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let item = DispatchWorkItem {
                withAnimation { feedbackText = nil }
                NSApplication.shared.keyWindow?.close()
            }
            feedbackWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduced ? 0 : 1.0), execute: item)
        }
    }

    private func simulatePaste() {
        // Give the previous app 150ms to become the key responder before sending ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // .combinedSessionState avoids contaminating the event with currently-held hardware keys
            let src = CGEventSource(stateID: .combinedSessionState)
            let vKey: CGKeyCode = 9  // 'v'
            let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
            down?.flags = .maskCommand
            up?.flags   = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}

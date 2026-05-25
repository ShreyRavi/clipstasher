import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: ClipStore
    @State private var selectedTab = "preferences"

    var body: some View {
        TabView(selection: $selectedTab) {
            PreferencesTab()
                .environmentObject(store)
                .tabItem { Label("Preferences", systemImage: "gearshape") }
                .tag("preferences")

            AboutTab()
                .environmentObject(store)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag("about")
        }
        .frame(width: 380, height: 320)
    }
}

// MARK: - Preferences Tab

private struct PreferencesTab: View {
    @EnvironmentObject private var store: ClipStore
    @State private var historyLimit: Int = 1000
    @State private var launchAtLogin: Bool = false
    @AppStorage("clickToPaste") private var clickToPaste = true

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Click to Paste", isOn: $clickToPaste)
                Text(clickToPaste
                     ? "Clicking a clip pastes it directly into the active app. Requires Accessibility access."
                     : "Clicking a clip copies to clipboard only. No Accessibility access needed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("History") {
                Stepper(value: $historyLimit, in: 100...1000, step: 100) {
                    HStack {
                        Text("History Limit")
                        Spacer()
                        Text("\(historyLimit)")
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: historyLimit) { newValue in
                    store.historyLimit = newValue
                }
                Text("100–1000 items. Pinned clips are never pruned.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            historyLimit = store.historyLimit
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    @EnvironmentObject private var store: ClipStore
    @State private var hashCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // App identity
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipstasher")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Binary SHA256
                VStack(alignment: .leading, spacing: 4) {
                    Text("Binary SHA256")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(store.binarySHA256())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(hashCopied ? "Copied!" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(store.binarySHA256(), forType: .string)
                            ClipboardMonitor.shared.markSelfWrite()
                            hashCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                hashCopied = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Data location
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(ClipStore.appSupportDir.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Open in Finder") {
                            store.openDataFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // GitHub Repository
                Button("GitHub Repository ↗") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/ShreyRavi/clipstasher")!)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                // GitHub Issues
                Button("GitHub Issues ↗") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/ShreyRavi/clipstasher/issues")!)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                // GitHub Sponsors
                Button("Support on GitHub Sponsors ↗") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/ShreyRavi")!)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Divider()

                // Encryption notice
                Text("Text clips are encrypted at rest with AES-256-GCM. Key stored in macOS Keychain. Image files and their paths are not encrypted. Any process running as the same user can access the Keychain key — this is not a substitute for FileVault.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
            }
            .padding()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

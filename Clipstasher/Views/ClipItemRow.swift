import SwiftUI
import AppKit

struct ClipItemRow: View {
    let clip: Clip
    let onCopy: () -> Void
    let onPin: () -> Void

    @State private var isHovered = false
    @State private var isRevealed = false  // sensitive content hover reveal
    @State private var isSelected = false

    private var isSensitive: Bool {
        clip.contentType == "text" && SensitiveContentDetector.isSensitive(clip.content)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            contentPreview
            Spacer(minLength: 4)
            pinButton
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onCopy() }
        .onHover { hovering in
            isHovered = hovering
            if !hovering { isRevealed = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to copy")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Content preview

    @ViewBuilder
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            if clip.isImage {
                imagePreview
            } else {
                textPreview
            }
            metadataRow
        }
    }

    @ViewBuilder
    private var textPreview: some View {
        let text = Text(clip.content)
            .font(.body)
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)

        if isSensitive && !isRevealed {
            text.blur(radius: 4)
                .overlay(
                    Button("Reveal") { isRevealed = true }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isHovered ? 1 : 0)
                )
        } else {
            text
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Image")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            Text(clip.relativeTimeString())
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)

            if isSensitive {
                Text("● secret")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(nsColor: .systemRed))
            }
        }
    }

    // MARK: - Pin button

    private var pinButton: some View {
        Button(action: onPin) {
            Image(systemName: clip.pinned ? "star.fill" : "star")
                .font(.system(size: 11))
                .foregroundColor(clip.pinned ? Color(nsColor: .systemYellow) : Color(nsColor: .tertiaryLabelColor))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: clip.pinned)
        .help(clip.pinned ? "Unpin" : "Pin")
    }

    // MARK: - Background

    private var rowBackground: some View {
        Group {
            if isSensitive {
                Color(nsColor: .systemRed).opacity(0.06)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let preview = clip.isImage ? "Image" : String(clip.content.prefix(80))
        let pinned = clip.pinned ? ", pinned" : ""
        return "\(preview), copied \(clip.relativeTimeString())\(pinned)"
    }
}

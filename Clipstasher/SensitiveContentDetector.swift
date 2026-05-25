import Foundation

struct SensitiveContentDetector {
    private static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"sk-[A-Za-z0-9]{20,}"#),
        try! NSRegularExpression(pattern: #"ghp_[A-Za-z0-9]{36}"#),
        try! NSRegularExpression(pattern: #"Bearer [A-Za-z0-9\-._~+/]+=*"#),
        try! NSRegularExpression(pattern: #"[A-Z_]{3,}=[^\s"']{4,}"#),
    ]

    static func isSensitive(_ content: String) -> Bool {
        let range = NSRange(content.startIndex..., in: content)
        return patterns.contains { $0.firstMatch(in: content, range: range) != nil }
    }
}

import XCTest
@testable import Clipstasher

final class SensitiveContentDetectorTests: XCTestCase {

    // MARK: - Not sensitive

    func testEmptyStringNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive(""))
    }

    func testNormalCodeNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive("let x = 42"))
    }

    func testURLNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive("https://example.com/path?q=value"))
    }

    func testPlainTextNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive("The quick brown fox jumps over the lazy dog"))
    }

    func testJSONNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive(#"{"key": "value", "count": 42}"#))
    }

    // MARK: - sk- API key pattern

    func testSKKeyExactMinLength() {
        // sk- + exactly 20 alphanumeric chars = minimum match
        let key = "sk-" + String(repeating: "a", count: 20)
        XCTAssertTrue(SensitiveContentDetector.isSensitive(key))
    }

    func testSKKeyOneBelowMinimum() {
        // sk- + 19 chars = does NOT match {20,}
        let key = "sk-" + String(repeating: "a", count: 19)
        XCTAssertFalse(SensitiveContentDetector.isSensitive(key))
    }

    func testSKKeyLong() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("sk-abcdefghijklmnopqrstuvwxyz01234567890A"))
    }

    func testSKKeyEmbeddedInText() {
        let content = "my key is sk-" + String(repeating: "x", count: 25) + " please keep it safe"
        XCTAssertTrue(SensitiveContentDetector.isSensitive(content))
    }

    func testSKKeyWithInternalDashNotSensitive() {
        // Real Anthropic keys "sk-ant-api03-..." have dashes — pattern requires alphanumeric only
        // "sk-" + "ant" (3 chars) + "-" breaks the [A-Za-z0-9]{20,} match
        let key = "sk-ant-api03-" + String(repeating: "x", count: 20)
        XCTAssertFalse(SensitiveContentDetector.isSensitive(key),
                       "Pattern sk-[A-Za-z0-9]{20,} does not match internal dashes")
    }

    // MARK: - ghp_ GitHub token pattern

    func testGHPTokenExact36Chars() {
        // ghp_ + exactly 36 alphanumeric chars
        let token = "ghp_" + String(repeating: "A", count: 36)
        XCTAssertTrue(SensitiveContentDetector.isSensitive(token))
    }

    func testGHPTokenTooShort() {
        // ghp_ + 35 chars = does NOT match {36}
        let token = "ghp_" + String(repeating: "A", count: 35)
        XCTAssertFalse(SensitiveContentDetector.isSensitive(token))
    }

    func testGHPTokenRealWorldFormat() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh12"))
    }

    func testGHPPrefixOnlyNotSensitive() {
        XCTAssertFalse(SensitiveContentDetector.isSensitive("ghp_short"))
    }

    // MARK: - Bearer token pattern

    func testBearerTokenBasic() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive(
            "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
    }

    func testBearerTokenWithSpecialChars() {
        // Pattern allows -, ., _, ~, +, /, = in the token value
        XCTAssertTrue(SensitiveContentDetector.isSensitive("Bearer abc.def-ghi_jkl~mno+pqr/stu="))
    }

    func testBearerTokenMinimum() {
        // Bearer + space + single char — matches [A-Za-z0-9...]{1}
        XCTAssertTrue(SensitiveContentDetector.isSensitive("Bearer x"))
    }

    func testBearerPrefixOnlyNotSensitive() {
        // "Bearer " with no token value — [A-Za-z0-9...]+  requires 1+ chars
        XCTAssertFalse(SensitiveContentDetector.isSensitive("Bearer "))
    }

    // MARK: - Env var pattern [A-Z_]{3,}=[^\s"']{4,}

    func testEnvVarLong() {
        XCTAssertTrue(SensitiveContentDetector.isSensitive("DATABASE_URL=postgres://user:pass@host/db"))
    }

    func testEnvVarExact4CharValue() {
        // Minimum: 3+ uppercase key, = , 4+ non-space/quote value
        XCTAssertTrue(SensitiveContentDetector.isSensitive("ABC=abcd"))
    }

    func testEnvVarShortValueNotSensitive() {
        // Value has only 3 chars — {4,} requires 4+
        XCTAssertFalse(SensitiveContentDetector.isSensitive("ABC=xyz"))
    }

    func testEnvVarShortKeyNotSensitive() {
        // Key "AB" is only 2 uppercase chars — {3,} requires 3+
        XCTAssertFalse(SensitiveContentDetector.isSensitive("AB=longvalue"))
    }

    func testEnvVarLowercaseKeyNotSensitive() {
        // Pattern requires uppercase [A-Z_]; lowercase keys don't match
        XCTAssertFalse(SensitiveContentDetector.isSensitive("database_url=postgres://user:pass@host"))
    }

    func testEnvVarValueWithSpaceNotSensitive() {
        // Space in value breaks [^\s] match — splits at first space
        XCTAssertFalse(SensitiveContentDetector.isSensitive("ABC=has space value"))
    }

    // MARK: - Multiline content

    func testMultilineWithSecretOnOneLine() {
        let content = "import Foundation\n// API key below\nsk-" + String(repeating: "k", count: 30)
        XCTAssertTrue(SensitiveContentDetector.isSensitive(content))
    }

    func testMultilineAllNormalLinesNotSensitive() {
        let content = "line one\nline two\nline three"
        XCTAssertFalse(SensitiveContentDetector.isSensitive(content))
    }
}

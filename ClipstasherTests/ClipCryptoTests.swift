import XCTest
import CryptoKit
@testable import Clipstasher

final class ClipCryptoTests: XCTestCase {

    private var key: SymmetricKey!

    override func setUp() {
        key = SymmetricKey(size: .bits256)
    }

    func testEncryptDecryptRoundTrip() throws {
        let plaintext = "hello clipboard"
        let encrypted = try ClipCrypto.encrypt(plaintext, key: key)
        let decrypted = ClipCrypto.decrypt(encrypted, key: key)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptedValueHasPrefix() throws {
        let encrypted = try ClipCrypto.encrypt("test", key: key)
        XCTAssertTrue(encrypted.hasPrefix(ClipCrypto.encPrefix))
    }

    func testEncryptedValueIsNotPlaintext() throws {
        let plaintext = "secret key sk-" + String(repeating: "x", count: 30)
        let encrypted = try ClipCrypto.encrypt(plaintext, key: key)
        XCTAssertNotEqual(encrypted, plaintext)
        XCTAssertFalse(encrypted.contains("secret key"))
    }

    func testDecryptLegacyPlaintextPassthrough() {
        let plaintext = "old clip without prefix"
        let result = ClipCrypto.decrypt(plaintext, key: key)
        XCTAssertEqual(result, plaintext)
    }

    func testDecryptEmptyStringPassthrough() {
        XCTAssertEqual(ClipCrypto.decrypt("", key: key), "")
    }

    func testDecryptBadBase64Passthrough() {
        let bad = ClipCrypto.encPrefix + "not-valid-base64!!!"
        let result = ClipCrypto.decrypt(bad, key: key)
        XCTAssertEqual(result, bad, "Corrupted ciphertext must return stored value unchanged")
    }

    func testDecryptWrongKeyReturnsStoredValue() throws {
        let encrypted = try ClipCrypto.encrypt("secret", key: key)
        let wrongKey = SymmetricKey(size: .bits256)
        let result = ClipCrypto.decrypt(encrypted, key: wrongKey)
        XCTAssertEqual(result, encrypted, "Wrong key must return stored value, not crash")
    }

    func testTwoEncryptionsOfSamePlaintextDiffer() throws {
        let a = try ClipCrypto.encrypt("same", key: key)
        let b = try ClipCrypto.encrypt("same", key: key)
        XCTAssertNotEqual(a, b, "AES-GCM uses random nonce per encryption")
    }

    func testRoundTripMultilineContent() throws {
        let content = "line one\nline two\nДанные\u{1F4CB}"
        let encrypted = try ClipCrypto.encrypt(content, key: key)
        XCTAssertEqual(ClipCrypto.decrypt(encrypted, key: key), content)
    }

    func testRoundTripEmptyString() throws {
        let encrypted = try ClipCrypto.encrypt("", key: key)
        XCTAssertEqual(ClipCrypto.decrypt(encrypted, key: key), "")
    }
}

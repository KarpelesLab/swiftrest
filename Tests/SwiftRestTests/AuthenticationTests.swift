import XCTest
@testable import SwiftRest

final class AuthenticationTests: XCTestCase {

    func testTokenAuthenticationSign() async throws {
        let auth = TokenAuthentication(accessToken: "test-token-123")
        let request = URLRequest(url: URL(string: "https://example.com/api")!)

        let signedRequest = try await auth.sign(request: request)

        XCTAssertEqual(
            signedRequest.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token-123"
        )
    }

    func testTokenAuthenticationExpiration() async throws {
        let expiredAuth = TokenAuthentication(
            accessToken: "expired-token",
            expiresAt: Date().addingTimeInterval(-60) // 1 minute ago
        )
        let isExpired = await expiredAuth.isExpired
        XCTAssertTrue(isExpired)

        let validAuth = TokenAuthentication(
            accessToken: "valid-token",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
        let isValidExpired = await validAuth.isExpired
        XCTAssertFalse(isValidExpired)

        let noExpiryAuth = TokenAuthentication(accessToken: "no-expiry-token")
        let noExpiryIsExpired = await noExpiryAuth.isExpired
        XCTAssertFalse(noExpiryIsExpired)
    }

    func testTokenAuthenticationUpdate() async throws {
        let auth = TokenAuthentication(
            accessToken: "old-token",
            refreshToken: "old-refresh"
        )

        await auth.update(accessToken: "new-token", refreshToken: "new-refresh", expiresIn: 3600)

        let accessToken = await auth.accessToken
        let refreshToken = await auth.refreshToken
        let expiresAt = await auth.expiresAt

        XCTAssertEqual(accessToken, "new-token")
        XCTAssertEqual(refreshToken, "new-refresh")
        XCTAssertNotNil(expiresAt)
        XCTAssertGreaterThan(expiresAt!, Date())
    }

    func testInMemoryTokenStorage() async throws {
        let storage = InMemoryTokenStorage()

        // Initially empty
        let initial = try await storage.load()
        XCTAssertNil(initial)

        // Save tokens
        try await storage.save(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Load tokens
        let loaded = try await storage.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.accessToken, "access-123")
        XCTAssertEqual(loaded?.refreshToken, "refresh-456")
        XCTAssertNotNil(loaded?.expiresAt)

        // Clear tokens
        try await storage.clear()
        let cleared = try await storage.load()
        XCTAssertNil(cleared)
    }

    func testAPIKeyAuthenticationInit() throws {
        // Valid 32-byte key (base64)
        let validSecret = Data(repeating: 0x42, count: 32).base64EncodedString()
        let auth = try APIKeyAuthentication(keyId: "key-123", secret: validSecret)
        XCTAssertEqual(auth.keyId, "key-123")

        // Invalid length
        let shortSecret = Data(repeating: 0x42, count: 16).base64EncodedString()
        XCTAssertThrowsError(try APIKeyAuthentication(keyId: "key-123", secret: shortSecret)) { error in
            guard case let APIKeyError.invalidKeyLength(expected, got) = error else {
                XCTFail("Expected invalidKeyLength error")
                return
            }
            XCTAssertEqual(expected, 32)
            XCTAssertEqual(got, 16)
        }

        // Invalid base64
        XCTAssertThrowsError(try APIKeyAuthentication(keyId: "key-123", secret: "not-valid-base64!@#")) { error in
            XCTAssertEqual(error as? APIKeyError, APIKeyError.invalidSecret)
        }
    }

    func testAPIKeyAuthenticationSign() async throws {
        let keyData = Data(repeating: 0x42, count: 32)
        let secret = keyData.base64EncodedString()
        let auth = try APIKeyAuthentication(keyId: "key-123", secret: secret)

        var request = URLRequest(url: URL(string: "https://example.com/api/test?foo=bar")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"test\":true}".utf8)

        let signedRequest = try await auth.sign(request: request)

        // Check that auth params were added
        let url = signedRequest.url!.absoluteString
        XCTAssertTrue(url.contains("_key=key-123"))
        XCTAssertTrue(url.contains("_time="))
        XCTAssertTrue(url.contains("_nonce="))
        XCTAssertTrue(url.contains("_sign="))
    }

    func testBase64URLEncoding() {
        // Standard base64 with + and /
        let data = Data([0xfb, 0xff, 0xfe])
        let standard = data.base64EncodedString()
        let urlSafe = data.base64URLEncodedString()

        XCTAssertTrue(standard.contains("+") || standard.contains("/") || standard.contains("="))
        XCTAssertFalse(urlSafe.contains("+"))
        XCTAssertFalse(urlSafe.contains("/"))
        XCTAssertFalse(urlSafe.contains("="))

        // Decode base64url
        let decoded = Data(base64URLEncoded: urlSafe)
        XCTAssertEqual(decoded, data)
    }

    func testBase64URLDecoding() {
        // Standard base64
        let standardEncoded = "SGVsbG8gV29ybGQh"
        let standardDecoded = Data(base64URLEncoded: standardEncoded)
        XCTAssertEqual(String(data: standardDecoded!, encoding: .utf8), "Hello World!")

        // URL-safe base64 with - and _
        let urlSafeEncoded = "SGVsbG8tV29ybGRf"
        let urlSafeDecoded = Data(base64URLEncoded: urlSafeEncoded)
        XCTAssertNotNil(urlSafeDecoded)
    }
}

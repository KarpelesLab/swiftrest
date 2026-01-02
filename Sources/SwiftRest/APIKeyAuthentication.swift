import Foundation
import CryptoKit

/// API Key authentication using Ed25519 signing
public struct APIKeyAuthentication: RestAuthentication {
    /// API Key ID
    public let keyId: String

    /// Ed25519 private key for signing
    private let privateKey: Curve25519.Signing.PrivateKey

    /// Initialize with key ID and base64-encoded secret
    public init(keyId: String, secret: String) throws {
        self.keyId = keyId

        // Try base64url decoding first, then standard base64
        let secretData: Data
        if let data = Data(base64URLEncoded: secret) {
            secretData = data
        } else if let data = Data(base64Encoded: secret) {
            secretData = data
        } else {
            throw APIKeyError.invalidSecret
        }

        // Ed25519 private keys are 32 bytes
        guard secretData.count == 32 else {
            throw APIKeyError.invalidKeyLength(expected: 32, got: secretData.count)
        }

        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: secretData)
    }

    /// Initialize with key ID and raw private key data
    public init(keyId: String, privateKeyData: Data) throws {
        self.keyId = keyId
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    }

    /// Sign a request with the API key
    public func sign(request: URLRequest) async throws -> URLRequest {
        var signedRequest = request

        guard let url = request.url else {
            throw RestError.invalidURL("nil")
        }

        // Generate timestamp and nonce
        let timestamp = Int64(Date().timeIntervalSince1970)
        let nonce = UUID().uuidString

        // Build URL with auth parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "_key", value: keyId))
        queryItems.append(URLQueryItem(name: "_time", value: String(timestamp)))
        queryItems.append(URLQueryItem(name: "_nonce", value: nonce))
        components.queryItems = queryItems

        // Calculate body hash
        let bodyHash: String
        if let body = request.httpBody, !body.isEmpty {
            let hash = SHA256.hash(data: body)
            bodyHash = Data(hash).base64URLEncodedString()
        } else {
            bodyHash = ""
        }

        // Build signature input
        // Format: METHOD\nPATH?QUERY\nBODY_HASH
        let method = request.httpMethod ?? "GET"
        let pathAndQuery = components.path + (components.query.map { "?\($0)" } ?? "")
        let signatureInput = "\(method)\n\(pathAndQuery)\n\(bodyHash)"

        // Sign with Ed25519
        let signatureData = try privateKey.signature(for: Data(signatureInput.utf8))
        let signature = signatureData.base64URLEncodedString()

        // Add signature to query
        queryItems.append(URLQueryItem(name: "_sign", value: signature))
        components.queryItems = queryItems

        signedRequest.url = components.url
        return signedRequest
    }
}

/// Errors specific to API key authentication
public enum APIKeyError: Error, LocalizedError, Equatable {
    case invalidSecret
    case invalidKeyLength(expected: Int, got: Int)
    case signingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidSecret:
            return "Invalid API key secret: must be base64 or base64url encoded"
        case .invalidKeyLength(let expected, let got):
            return "Invalid key length: expected \(expected) bytes, got \(got)"
        case .signingFailed:
            return "Failed to sign request"
        }
    }
}

// MARK: - Base64URL Extensions

extension Data {
    /// Initialize from base64url-encoded string
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        self.init(base64Encoded: base64)
    }

    /// Encode to base64url string (no padding)
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

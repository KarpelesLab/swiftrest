import Foundation

/// Protocol for REST API authentication methods
public protocol RestAuthentication: Sendable {
    /// Sign a request with authentication credentials
    func sign(request: URLRequest) async throws -> URLRequest
}

/// OAuth2 Bearer Token authentication
public actor TokenAuthentication: RestAuthentication {
    /// Access token
    public private(set) var accessToken: String

    /// Refresh token
    public private(set) var refreshToken: String?

    /// Token expiration date
    public private(set) var expiresAt: Date?

    /// Client ID for token refresh
    public let clientId: String?

    /// Client secret for token refresh (optional)
    public let clientSecret: String?

    /// Initialize with tokens
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        clientId: String? = nil,
        clientSecret: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    /// Check if the token is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// Sign a request with the bearer token
    public func sign(request: URLRequest) async throws -> URLRequest {
        var signedRequest = request
        signedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return signedRequest
    }

    /// Update tokens after refresh
    public func update(accessToken: String, refreshToken: String?, expiresIn: TimeInterval?) {
        self.accessToken = accessToken
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
        }
        if let expiresIn = expiresIn {
            self.expiresAt = Date().addingTimeInterval(expiresIn)
        }
    }

    /// Refresh the token using the provided client
    public func refresh(using client: RestClient) async throws {
        guard let refreshToken = refreshToken else {
            throw RestError.noRefreshToken
        }

        guard let clientId = clientId else {
            throw RestError.noClientId
        }

        var params: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]

        if let clientSecret = clientSecret {
            params["client_secret"] = clientSecret
        }

        // Use requestRaw for OAuth2 endpoint (returns nude JSON, not wrapped in result/data)
        let response: TokenResponse = try await client.requestRaw("OAuth2:token", method: .post, params: params)

        // Update tokens
        update(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )
    }
}

/// Token response from OAuth2 endpoint (nude JSON format)
private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let tokenType: String?
    // Note: uses snake_case decoding strategy, so no CodingKeys needed
}

/// Storage for persisting tokens
public protocol TokenStorage: Sendable {
    func save(accessToken: String, refreshToken: String?, expiresAt: Date?) async throws
    func load() async throws -> (accessToken: String, refreshToken: String?, expiresAt: Date?)?
    func clear() async throws
}

/// In-memory token storage (for testing)
public actor InMemoryTokenStorage: TokenStorage {
    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    public init() {}

    public func save(accessToken: String, refreshToken: String?, expiresAt: Date?) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public func load() async throws -> (accessToken: String, refreshToken: String?, expiresAt: Date?)? {
        guard let accessToken = accessToken else { return nil }
        return (accessToken, refreshToken, expiresAt)
    }

    public func clear() async throws {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
    }
}

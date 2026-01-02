import Foundation

/// Configuration for RestClient
public struct RestClientConfig: Sendable {
    /// URL scheme (http or https)
    public let scheme: String

    /// API host
    public let host: String

    /// Base path for REST endpoints
    public let restPath: String

    /// Client ID for authentication
    public let clientId: String?

    /// Context parameters to include with every request
    public let contextParams: [String: String]

    /// Request timeout in seconds
    public let requestTimeout: TimeInterval

    /// Resource timeout in seconds
    public let resourceTimeout: TimeInterval

    /// Upload request timeout in seconds
    public let uploadRequestTimeout: TimeInterval

    /// Upload resource timeout in seconds
    public let uploadResourceTimeout: TimeInterval

    /// Maximum connections per host
    public let maxConnectionsPerHost: Int

    /// Default configuration
    public static let `default` = RestClientConfig(
        scheme: "https",
        host: "www.atonline.com",
        restPath: "/_special/rest/",
        clientId: nil,
        contextParams: [:],
        requestTimeout: 60,
        resourceTimeout: 300,
        uploadRequestTimeout: 300,
        uploadResourceTimeout: 3600,
        maxConnectionsPerHost: 50
    )

    /// Create a custom configuration
    public init(
        scheme: String = "https",
        host: String,
        restPath: String = "/_special/rest/",
        clientId: String? = nil,
        contextParams: [String: String] = [:],
        requestTimeout: TimeInterval = 60,
        resourceTimeout: TimeInterval = 300,
        uploadRequestTimeout: TimeInterval = 300,
        uploadResourceTimeout: TimeInterval = 3600,
        maxConnectionsPerHost: Int = 50
    ) {
        self.scheme = scheme
        self.host = host
        self.restPath = restPath
        self.clientId = clientId
        self.contextParams = contextParams
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.uploadRequestTimeout = uploadRequestTimeout
        self.uploadResourceTimeout = uploadResourceTimeout
        self.maxConnectionsPerHost = maxConnectionsPerHost
    }

    /// Create configuration with context (language, timezone)
    public func withContext(language: String? = nil, timezone: String? = nil) -> RestClientConfig {
        var params = contextParams
        if let language = language {
            params["_ctx[l]"] = language
        }
        if let timezone = timezone {
            params["_ctx[t]"] = timezone
        }
        return RestClientConfig(
            scheme: scheme,
            host: host,
            restPath: restPath,
            clientId: clientId,
            contextParams: params,
            requestTimeout: requestTimeout,
            resourceTimeout: resourceTimeout,
            uploadRequestTimeout: uploadRequestTimeout,
            uploadResourceTimeout: uploadResourceTimeout,
            maxConnectionsPerHost: maxConnectionsPerHost
        )
    }

    /// Create configuration with client ID
    public func withClientId(_ clientId: String) -> RestClientConfig {
        return RestClientConfig(
            scheme: scheme,
            host: host,
            restPath: restPath,
            clientId: clientId,
            contextParams: contextParams,
            requestTimeout: requestTimeout,
            resourceTimeout: resourceTimeout,
            uploadRequestTimeout: uploadRequestTimeout,
            uploadResourceTimeout: uploadResourceTimeout,
            maxConnectionsPerHost: maxConnectionsPerHost
        )
    }
}
